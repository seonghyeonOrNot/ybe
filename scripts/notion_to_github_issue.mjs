import notionSdk from "@notionhq/client";
const { Client } = notionSdk;

const notion = new Client({ auth: process.env.NOTION_TOKEN });

const GH_TOKEN = process.env.GH_TOKEN;
const GH_OWNER = process.env.GH_OWNER;
const GH_REPO = process.env.GH_REPO;
const NOTION_DB_ID = process.env.NOTION_TICKET_DATABASE_ID;

// ✅ ai_label 허용 목록
const ALLOWED_AI_LABELS = new Set(["feature", "cs", "policy", "qa", "risk", "data"]);

function getPlainText(arr = []) {
  return arr.map((t) => t.plain_text).join("").trim();
}

function getProp(props, name) {
  const p = props?.[name];
  if (!p) return null;
  return p;
}

function readTitle(props, name) {
  const p = getProp(props, name);
  if (!p || p.type !== "title") return "";
  return getPlainText(p.title);
}

function readText(props, name) {
  const p = getProp(props, name);
  if (!p) return "";
  if (p.type === "rich_text") return getPlainText(p.rich_text);
  if (p.type === "text") return p.text ?? "";
  return "";
}

function readSelect(props, name) {
  const p = getProp(props, name);
  if (!p || p.type !== "select") return "";
  return p.select?.name ?? "";
}

function readMultiSelect(props, name) {
  const p = getProp(props, name);
  if (!p || p.type !== "multi_select") return [];
  return (p.multi_select ?? [])
    .map((x) => x?.name ?? "")
    .map((s) => s.trim())
    .filter(Boolean);
}

function readStatus(props, name) {
  const p = getProp(props, name);
  if (!p || p.type !== "status") return "";
  return p.status?.name ?? "";
}

function readCheckbox(props, name) {
  const p = getProp(props, name);
  if (!p || p.type !== "checkbox") return false;
  return !!p.checkbox;
}

// Notion rich_text / title 텍스트 공통 읽기 (catalog_query용)
function readRichOrTitleText(props, name) {
  const p = getProp(props, name);
  if (!p) return "";
  if (p.type === "rich_text") return getPlainText(p.rich_text);
  if (p.type === "title") return getPlainText(p.title);
  return "";
}

async function createGithubIssue({ title, body, labels = [] }) {
  const res = await fetch(
    `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/issues`,
    {
      method: "POST",
      headers: {
        Authorization: `token ${GH_TOKEN}`,
        "Content-Type": "application/json",
        Accept: "application/vnd.github+json",
        "User-Agent": "notion-issue-bot",
      },
      body: JSON.stringify({ title, body, labels }),
    }
  );

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GitHub Issue 생성 실패: ${res.status} ${text}`);
  }
  return await res.json();
}

function buildCatalogBlock(catalogQuery) {
  const catalogFile = "data/catalog/features.csv";
  return `
## Catalog Reference (MUST USE)
- File: ${catalogFile}
- Query:
${catalogQuery || "(empty)"}

## Claude Instructions
1) 먼저 ${catalogFile} 를 Query로 검색해 관련 기능 3~5개를 요약해라.
2) 문서 최상단에 "카탈로그 참고 결과" 섹션을 만들고, 뽑은 행을 feature_id/대메뉴/중메뉴/소메뉴/요약 형태로 나열해라.
3) 그 행들의 용어/정책/절차를 재사용해 가이드를 작성해라.
4) 이슈 내용과 카탈로그가 다르면 "변경점" 섹션에 (카탈로그 vs 이슈) 차이를 표로 기록해라.
5) 매칭 실패하면 "카탈로그 매칭 실패"라고 쓰고, 어떤 키워드로 찾았는지 남겨라.
`.trim();
}

async function main() {
  console.log("🔎 Query Notion DB...");

  const resp = await notion.databases.query({
    database_id: NOTION_DB_ID,
    filter: {
      and: [
        { property: "Status", status: { equals: "Ready for Dev" } },
        { property: "Issue Created?", checkbox: { equals: false } },
      ],
    },
  });

  console.log(`✅ Found ${resp.results.length} items`);

  for (const page of resp.results) {
    const props = page.properties;

    const featureName = readTitle(props, "Feature_Name") || "Untitled";

    const summary =
      readText(props, "Summary") ||
      readText(props, "Summary AI") ||
      "";

    const priority = readSelect(props, "Priority");

    // ✅ Notion: AI_Label (multi_select)
    const aiLabelsRaw = readMultiSelect(props, "AI_Label");
    const aiLabelsNorm = aiLabelsRaw.map((s) => s.toLowerCase());

    // 허용 목록과 매칭되는 라벨만 추출
    const aiLabelsToApply = aiLabelsNorm.filter((x) => ALLOWED_AI_LABELS.has(x));

    const status = readStatus(props, "Status");
    const issueCreated = readCheckbox(props, "Issue Created?");

    const catalogQuery = readRichOrTitleText(props, "catalog_query");

    console.log(`\n---\n📌 ${featureName}`);
    console.log(`Status=${status}, IssueCreated=${issueCreated}`);
    console.log(`AI_Label(raw)=${aiLabelsRaw.length ? aiLabelsRaw.join(", ") : "-"}`);
    console.log(`AI_Label(apply)=${aiLabelsToApply.length ? aiLabelsToApply.join(", ") : "-"}`);
    console.log(`CatalogQuery=${catalogQuery ? "OK" : "EMPTY"}`);

    // ✅ labels 구성
    const labels = [];

    if (priority) labels.push(priority.toLowerCase());

    // ✅ AI_Label 매핑 라벨 자동 부착 (ai-run은 수동)
    for (const l of aiLabelsToApply) labels.push(l);

    // ✅ 기존 라벨 유지
    labels.push("ready-for-guide");

    if (!catalogQuery) labels.push("needs-catalog-query");

    // 중복 제거
    const labelsDedup = [...new Set(labels)];

    console.log(`Labels to create=${labelsDedup.join(", ")}`);

    const specId =
      props?.Spec_ID?.type === "unique_id"
        ? props.Spec_ID.unique_id?.prefix + props.Spec_ID.unique_id?.number
        : props?.Spec_ID?.type === "auto_increment_id"
          ? props.Spec_ID.auto_increment_id
          : "-";

    const catalogBlock = buildCatalogBlock(catalogQuery);

    const body = `
${catalogBlock}

---

### 📌 Notion
- Page: ${page.url}
- Spec_ID: ${specId}

### ✅ Summary
${summary || "-"}

### 🧩 Meta
- Priority: ${priority || "-"}
- Notion Status: ${status}
- AI_Label: ${aiLabelsToApply.length ? aiLabelsToApply.join(", ") : "-"}
`.trim();

    const issue = await createGithubIssue({
      title: `[${priority || "TASK"}] ${featureName}`,
      body,
      labels: labelsDedup,
    });

    console.log(`✅ Created Issue: ${issue.html_url}`);

    await notion.pages.update({
      page_id: page.id,
      properties: {
        "GitHub Issue URL": { url: issue.html_url },
        "Issue Created?": { checkbox: true },
      },
    });

    console.log("🔁 Notion updated");
  }

  console.log("\n🎉 Done");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

import notionSdk from "@notionhq/client";
const { Client } = notionSdk;

const notion = new Client({ auth: process.env.NOTION_TOKEN });

const GH_TOKEN = process.env.GH_TOKEN;
const GH_OWNER = process.env.GH_OWNER;
const GH_REPO = process.env.GH_REPO;
const NOTION_DB_ID = process.env.NOTION_TICKET_DATABASE_ID;

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

async function createGithubIssue({ title, body, labels = [] }) {
  const res = await fetch(`https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/issues`, {
    method: "POST",
    headers: {
      Authorization: `token ${GH_TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/vnd.github+json",
      "User-Agent": "notion-issue-bot",
    },
    body: JSON.stringify({ title, body, labels }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GitHub Issue 생성 실패: ${res.status} ${text}`);
  }
  return await res.json();
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
    const summary = readText(props, "Summary");
    const priority = readSelect(props, "Priority");

    const status = readStatus(props, "Status");
    const issueCreated = readCheckbox(props, "Issue Created?");

    console.log(`\n---\n📌 ${featureName}`);
    console.log(`Status=${status}, IssueCreated=${issueCreated}`);

    const labels = [];
    if (priority) labels.push(priority.toLowerCase());

    const body = `
### 📌 Notion
- Page: ${page.url}
- Spec_ID: ${props?.Spec_ID?.type === "unique_id" ? props.Spec_ID.unique_id?.prefix + props.Spec_ID.unique_id?.number : (props?.Spec_ID?.type === "auto_increment_id" ? props.Spec_ID.auto_increment_id : "-")}

### ✅ Summary
${summary || "-"}

### 🧩 Meta
- Priority: ${priority || "-"}
- Notion Status: ${status}
`.trim();

    const issue = await createGithubIssue({
      title: `[${priority || "TASK"}] ${featureName}`,
      body,
      labels,
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

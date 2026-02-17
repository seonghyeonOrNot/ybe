# scripts/csv_to_tsv.py
import csv
import sys

def main():
    if len(sys.argv) != 3:
        print("Usage: python scripts/csv_to_tsv.py <src.csv> <dst.tsv>")
        sys.exit(1)

    src, dst = sys.argv[1], sys.argv[2]

    with open(src, "r", encoding="utf-8") as f_in:
        # Google Sheets CSV는 보통 표준 CSV. newline 처리는 파서가 함.
        reader = csv.reader(f_in)
        rows = list(reader)

    with open(dst, "w", encoding="utf-8", newline="") as f_out:
        for row in rows:
            f_out.write("\t".join(row) + "\n")

if __name__ == "__main__":
    main()

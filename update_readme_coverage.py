#!/usr/bin/env python3

import re
import sys

def read_file_content(filepath):
    """Reads the content of a file.

    Args:
        filepath (str): The path to the file.

    Returns:
        str: The content of the file, or None if an error occurs.
    """
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except FileNotFoundError:
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error reading file {filepath}: {e}", file=sys.stderr)
        return None

def extract_summary_from_report(report_content):
    """Extracts the summary table from the luacov report content.

    Args:
        report_content (str): The content of luacov.report.out.

    Returns:
        str: The extracted summary table, or None if not found.
    """
    if not report_content:
        return None

    summary_start_pattern = r"^===============================================================================\nSummary\n==============================================================================="
    match = re.search(summary_start_pattern, report_content, re.MULTILINE)

    if not match:
        print("Error: Summary section start not found in luacov.report.out", file=sys.stderr)
        return None

    summary_content_after_header = report_content[match.end():].lstrip()

    # The summary table ends before any potential subsequent text or new sections (e.g. another ===...=== block)
    # or at the end of the file.
    summary_end_match = re.search(r"\n\s*={3,}", summary_content_after_header, re.MULTILINE)
    if summary_end_match:
        summary_table = summary_content_after_header[:summary_end_match.start()]
    else:
        summary_table = summary_content_after_header

    # The summary table includes its header, which is the line after "===" and "Summary" lines.
    # We need to find the actual table header line.
    # The table starts after the second "===" line.
    # The extracted summary_table starts with the line immediately after the second "==="
    # and includes the actual table header.

    # We need to ensure we capture the table header and all lines until "Total".
    # Let's find the "Total" line and include everything up to it.
    total_line_match = re.search(r"^\s*Total\s+.*$", summary_table, re.MULTILINE)
    if not total_line_match:
        print("Error: 'Total' line not found in the summary table.", file=sys.stderr)
        # Return what we have so far, or handle as a more critical error
        # For now, let's assume the summary table might be malformed if Total is missing
        # but the initial extraction logic should capture up to the next section or EOF.
        # The current logic for summary_table should be okay if "Total" is the last meaningful line.
        # However, the prompt says "The summary table ends before any potential subsequent text or new sections."
        # The current summary_table extraction already respects this.
        # Let's refine to ensure we get the header and content correctly.

    # The summary_table currently holds the content from *after* the "Summary" and "===" lines.
    # This means it starts with the actual table header.
    # We need to ensure it includes the "Total" line and everything before it within that block.

    # Let's re-evaluate the end condition. The table ends before *another* "===" section.
    # The initial `summary_table` extraction should be correct based on that.
    # The key is that `summary_content_after_header` is the start, and `summary_end_match` finds the next separator.

    if not summary_table.strip():
        print("Error: Extracted summary table is empty.", file=sys.stderr)
        return None

    return summary_table.strip()


def update_readme(readme_content, summary_table):
    """Updates the README content with the summary table.

    Args:
        readme_content (str): The content of README.md.
        summary_table (str): The summary table to insert.

    Returns:
        str: The updated README content, or None if the target line is not found.
    """
    if not readme_content or not summary_table:
        return None

    target_line = "The latest report is committed to the repository and can be viewed here: [luacov.report.out](luacov.report.out)."
    replacement_text = f"""The latest summary is:

```markdown
{summary_table}
```"""

    if target_line not in readme_content:
        print(f"Error: Target line not found in README.md:\n'{target_line}'", file=sys.stderr)
        return None

    updated_readme_content = readme_content.replace(target_line, replacement_text)
    return updated_readme_content

def write_file_content(filepath, content):
    """Writes content to a file.

    Args:
        filepath (str): The path to the file.
        content (str): The content to write.

    Returns:
        bool: True if successful, False otherwise.
    """
    try:
        with open(filepath, 'w') as f:
            f.write(content)
        return True
    except Exception as e:
        print(f"Error writing to file {filepath}: {e}", file=sys.stderr)
        return False

def main():
    """Main function to update README with luacov summary."""
    luacov_report_path = "luacov.report.out"
    readme_path = "README.md"

    report_content = read_file_content(luacov_report_path)
    if report_content is None:
        sys.exit(1)

    summary_table = extract_summary_from_report(report_content)
    if summary_table is None:
        sys.exit(1)

    # Ensure summary_table is not empty after stripping
    if not summary_table.strip():
        print("Error: Extracted summary table is empty after stripping. Cannot update README.", file=sys.stderr)
        sys.exit(1)

    readme_content = read_file_content(readme_path)
    if readme_content is None:
        sys.exit(1)

    updated_readme = update_readme(readme_content, summary_table)
    if updated_readme is None:
        sys.exit(1)

    if not write_file_content(readme_path, updated_readme):
        sys.exit(1)

    print(f"Successfully updated {readme_path} with the coverage summary.")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3

import sys
import re
import tap


def sanitize_description(description):
    """
    Sanitizes the description by replacing spaces with dashes, removing special characters, and avoiding double dashes.

    Args:
        description (str): The test description.

    Returns:
        str: The sanitized description.
    """
    description = description.replace(" ", "-")
    description = re.sub(
        r"[^a-zA-Z0-9\-]", "", description
    )  # Remove special characters
    description = re.sub(
        r"-+", "-", description
    )  # Replace multiple dashes with a single dash
    description = description.strip("-")  # Remove leading and trailing dashes
    return description


def format_output(result, description):
    """
    Formats the parsed data into the desired output format.

    Args:
        result (str): The test result (pass, fail, skip).
        description (str): The test description.

    Returns:
        str: The formatted output string.
    """
    sanitized_description = sanitize_description(description)
    return f"{sanitized_description} {result}\n"


def main():
    """
    Main function to parse input, process each line, and output the results.
    """
    try:
        plan = tap.parser.Parser()
        test_cases = plan.parse_stream(sys.stdin)

        for test_case in test_cases:
            if test_case.ok:
                result = "pass"
            elif test_case.skip:
                result = "skip"
            else:
                result = "fail"

            description = test_case.description or ""
            formatted_line = format_output(result, description)
            sys.stdout.write(formatted_line)

    except Exception as e:
        sys.stderr.write(f"Unexpected error: {e}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()

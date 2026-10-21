# Wrap every contextual help page before pagination

Help uses the existing text wrapper to retain every character within 40 columns and then paginates the resulting rows in groups of 16. The final page list includes contextual, general and flight reference pages, so appended instructions receive the same bounds.

The existing all-screen help regression retains its row-width, page-height, rendering, navigation and pause assertions. Source validation is pending; this change has no completed runtime, full-CI or release result. Motivation: [issue](ISSUE-help-page-wrapping.md).

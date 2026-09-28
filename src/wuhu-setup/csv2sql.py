#!/usr/bin/env python3
"""
Convert a .csv table into an SQL 'INSERT INTO' statement.

The table must have a header row. Only columns with a header in the format
'tablename:column' are processed. Optionally, a column ':order' can be used
to specify the order in which the rows shall be inserted.

In order to be inserted, more than half of the database-relevant columns in a
row must be filled.
"""
import argparse
import csv
import io
import re
import sys
import urllib.request

g_newline = None


def value2sql(x: int|str):
    if isinstance(x, int): return str(x)
    x = x.replace('\\', '\\\\').replace("'", "\\'").replace('\t', '\\t').replace('\n', '\\n')
    global g_newline
    if g_newline:
        x = x.replace(g_newline, '\\n')
    return "'" + x + "'"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("infile", help="input CSV file or Google Sheets URL; '-' = stdin")
    parser.add_argument("-o", "--outfile", help="output file (default: stdout)")
    parser.add_argument("-n", "--newline", help="character sequence to replace by a newline in text fields")
    args = parser.parse_args()
    g_newline = args.newline

    # read table
    if m := re.match(r'(https?://docs.google.com/spreadsheets/d/[^/]+)/edit\?gid=(\d+)', args.infile, flags=re.I):
        print("loading CSV export from Google Sheets document", args.infile, "...")
        url = m.group(1) + "/export?format=csv&gid=" + m.group(2)
        with urllib.request.urlopen(url) as f:
            infile = io.StringIO(f.read().decode('utf-8', 'replace'))
    elif args.infile != '-':
        print("reading input from", sys.argv[1], "...", file=sys.stderr)
        infile = open(args.infile, 'r')
    else:
        print("reading input from stdin; press", "^Z and Enter" if (sys.platform == 'win32') else "^D", "when done:", file=sys.stderr)
        infile = sys.stdin
    table = list(csv.reader(infile))
    infile.close()

    # build a column index
    idx2col = {}
    col2idx = {}
    is_int = set()
    for i, col in enumerate(zip(*table), start=2):
        if not(':' in col[0]):
            continue
        check_int = [x.strip().isdigit() for x in col[1:] if x.strip()]
        if any(check_int) and all(check_int):
            is_int.add(i)
        idx2col[i] = col[0]
        col2idx[col[0]] = i

    # which table are we going to populate?
    dbtable = { c.split(':', 1)[0] for c in col2idx }
    dbtable = { c for c in dbtable if c }
    if not dbtable:
        print("no columns to export.", file=sys.stderr)
        sys.exit(1)
    if len(dbtable) > 1:
        print("table name is ambiguous:", " / ".join(sorted(dbtable)), file=sys.stderr)
        sys.exit(1)
    dbtable = dbtable.pop()
    print("table to export:", dbtable)

    # turn idx2col into an (index, column) list of the current table only,
    # and prepare query
    idx2col = sorted((i, c.split(':', 1)[-1]) for i,c in idx2col.items() if c.split(':', 1)[0] == dbtable)

    # helper function: parse a cell as integer, if marked as such
    def parse_col(i: int, value: str):
        if not(i in is_int): return value
        value = value.strip()
        return int(value) if value else 0

    # sort table by adding two columns first: a (parsed) copy of the :order,
    # and the original line number as tie-breaker
    order_col = col2idx.get(':order')
    table = sorted([parse_col(order_col, row[order_col-2]) if order_col else None, i] + row for i, row in enumerate(table[1:]))

    # produce the actual VALUES lines for the relevant rows
    values = []
    for row in table:
        if sum(bool(row[i].strip()) for i,c in idx2col) <= (len(idx2col) // 2):
            continue
        values.append("(" + ", ".join(value2sql(parse_col(i, row[i])) for i,c in idx2col) + ")")

    # generate query
    if not values:
        print("no rows to export.", file=sys.stderr)
        sys.exit(1)
    query = "INSERT INTO " + dbtable + "(" + ", ".join(c for i,c in idx2col) + ") VALUES " + ", ".join(values) + ";"
    if args.outfile:
        with open(args.outfile, 'w') as f:
            print(query, file=f)
    else:
        print(query)

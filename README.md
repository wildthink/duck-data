# DuckData
WARNING: This project is just beginning so nothing useful yet!

## Overview
The primary goal is to leverage Pointfree's [swift-structured-query](https://swiftpackageindex.com/pointfreeco/swift-structured-queries)
to provide a Swift type-safe interface [DuckDB](https://duckdb.org/why_duckdb) to define 
SQL table schemas and create SQL statements of all kinds. If you 
are unfamiliar with these then run over right now to learn and show
your support to both!! (This is an **unpaid** indorsment!).

All that said, onto the plan.

DuckDB is special in its own right. As a columnar database, the
interace we want to provide will be optimized for its use. While
we will include the standard SQL row-oriented interface for
compatiability and ease of use, the performance is likely to
be sub-optimal compared to what DuckDB delivers when dealing
with larger data sets. More on this later.  


### Resources

#### Pointfree
- [SQLiteData](https://swiftpackageindex.com/pointfreeco/sqlite-data)
- [swift-structured-query](https://swiftpackageindex.com/pointfreeco/swift-structured-queries)

#### ParCore
[Original Project](https://github.com/parquette/ParCore)

A cross-platform data analytics library based on R & Pandas 
DataFrames and compatible with the [TabularData framework](https://developer.apple.com/documentation/tabulardata).


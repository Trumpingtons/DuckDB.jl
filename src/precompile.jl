# Pollis: a precompile workload, so that the first query of a session does not wait for Julia to compile
# DuckDB.jl (about 1.5 s). It runs when DuckDB.jl is precompiled, against the library named by
# JULIA_DUCKDB_LIBRARY, and is skipped when that library is not there.

using PrecompileTools: @compile_workload, @setup_workload

@setup_workload begin
    sql = """
        SELECT i::TINYINT AS a, i::SMALLINT AS b, i::INTEGER AS c, i::BIGINT AS d, i::UTINYINT AS e,
               i::USMALLINT AS f, i::UINTEGER AS g, i::UBIGINT AS h, i::HUGEINT AS j, i::FLOAT AS k,
               i::DOUBLE AS l, i::DECIMAL(9,2) AS m, i::DECIMAL(18,3) AS n, i % 2 = 0 AS o,
               'text ' || i AS p, DATE '2026-01-01' + i::INTEGER AS q, TIMESTAMP '2026-01-01 12:00:00' AS r,
               TIMESTAMPTZ '2026-01-01 12:00:00+00' AS s, TIME '12:00:00' AS t, INTERVAL 1 DAY AS u,
               gen_random_uuid() AS v, 'bytes'::BLOB AS w, [i, i + 1] AS x, {'k': i} AS y,
               CASE WHEN i = 1 THEN NULL ELSE i END AS z
        FROM range(3) AS t(i)
        """
    @compile_workload begin
        if isfile(libduckdb)
            for db in (DB(":memory:"), DB(":memory:"; config = ["autoload_known_extensions" => "false"]))
                con = DBInterface.connect(db)
                Tables.columntable(DBInterface.execute(con, sql))
                Tables.columntable(DBInterface.execute(db, sql))
                DBInterface.execute(db, "CREATE TABLE t AS SELECT range AS i, 'x' AS s FROM range(3)")
                stmt = DBInterface.prepare(db, "SELECT * FROM t WHERE i > ? AND s = ?")
                Tables.columntable(DBInterface.execute(stmt, (0, "x")))
                Tables.columntable(DBInterface.execute(db, "SELECT * FROM t WHERE i > \$1", [1]))
                Tables.columntable(DBInterface.execute(db, "SELECT count(*) FROM t"))
                Tables.rowtable(DBInterface.execute(db, "SELECT * FROM t"))
                for row in DBInterface.execute(db, "SELECT * FROM t")
                    row.i
                end
                DBInterface.close!(stmt)
                DBInterface.close!(con)
                DBInterface.close!(db)
            end
        end
    end
end

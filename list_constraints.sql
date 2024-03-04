/* based on https://dataedo.com/kb/query/postgresql/list-foreign-keys */
/* also found https://gist.github.com/jeffjohnson9046/5cff514a4fd2721e4acfcac56eaa2342 */

select kcu.table_name as foreign_table, rel_tco.table_name as primary_table
from information_schema.table_constraints tco
join information_schema.key_column_usage kcu
          on tco.constraint_schema = kcu.constraint_schema
          and tco.constraint_name = kcu.constraint_name
join information_schema.referential_constraints rco
          on tco.constraint_schema = rco.constraint_schema
          and tco.constraint_name = rco.constraint_name
join information_schema.table_constraints rel_tco
          on rco.unique_constraint_schema = rel_tco.constraint_schema
          and rco.unique_constraint_name = rel_tco.constraint_name
where tco.constraint_type = 'FOREIGN KEY'
group by kcu.table_schema,
         kcu.table_name,
         rel_tco.table_name,
         rel_tco.table_schema,
         kcu.constraint_name
order by kcu.table_schema,
         kcu.table_name;

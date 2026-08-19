from pyspark import pipelines as dp
import pandas as pd

catalog_name = spark.conf.get("catalog_name")
schema_name = spark.conf.get("schema_name")
volume_name = spark.conf.get("volume_name")
file_name = spark.conf.get("file_name")
bronze_table_name = spark.conf.get("bronze_table_name")

source_path = f"/Volumes/{catalog_name}/{schema_name}/{volume_name}/{file_name}"

@dp.materialized_view(name=bronze_table_name)
def bronze_table():
    # Load the raw route dictionary.
    route_dict = pd.read_pickle(source_path)

    # Preserve the dictionary key as route_id.
    route_list = [
        {"route_id": route_id, **route_data}
        for route_id, route_data in route_dict.items()
    ]

    # Convert to a Spark DataFrame and normalize the aspect field name.
    return spark.createDataFrame(route_list).withColumnRenamed(
        "unidentifiable element", "aspect"
    )
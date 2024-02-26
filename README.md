# w_test

## JSON File

```JSON
{
  "employees": [
    {"id": 1, "name": "John Doe", "position": "Manager"},
    {"id": 2, "name": "Jane Smith", "position": "Developer"}
  ]
}
```

## New Addition

To update the same JSON file rather than creating a new one, you can overwrite the existing JSON file in the DATA step after making the modifications. Here's an example:

```SAS
data input_json;
  infile 'path/to/input.json' truncover;
  input;
  json_input = _infile_;
run;

proc json in=input_json out=output_json;
  update employees append;
    id = 3;
    name = "Bob Johnson";
    position = "Analyst";
run;

data _null_;
  set output_json;
  file 'path/to/input.json';  /* Overwriting the same JSON file */
  put json_output;
run;
```

In this modified example:

- The first DATA step reads the JSON file into a dataset named input_json.
- The PROC JSON step updates the dataset to add a new employee.
- The DATA step with _null_ dataset and file statement overwrites the original JSON file with the updated content.

Make sure to replace 'path/to/input.json' with the actual path to your input JSON file. After running this code, your original JSON file will be updated with the new data.

## Update record

To change an entry in a JSON file and then output the modified content back to the same JSON file, you can use the PROC JSON step to update the specific values within the dataset, and then overwrite the original JSON file with the modified content. Here's an example:

```SAS
data input_json;
  infile 'path/to/input.json' truncover;
  input;
  json_input = _infile_;
run;

proc json in=input_json out=output_json;
  update employees;
    where id = 2; /* Specify the condition to identify the entry to be changed */
    name = "Jane Doe"; /* Modify the name */
    position = "Senior Developer"; /* Modify the position */
run;

data _null_;
  set output_json;
  file 'path/to/input.json';  /* Overwriting the same JSON file */
  put json_output;
run;
```

In this example:

- The DATA step reads the JSON file into a dataset named input_json.
- The PROC JSON step updates the dataset to change the values for an employee with id=2.
- The DATA step with _null_ dataset and file statement overwrites the original JSON file with the updated content.

Ensure you replace 'path/to/input.json' with the actual path to your input JSON file. This code will modify the specified entry in the JSON file and save the changes back to the same file.

Remember to adjust the conditions and values in the update statement according to your specific requirements.

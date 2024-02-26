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

## Interest

Certainly! If your interest rates have start and end dates, you'll need to consider these date ranges when calculating the interest. Here's an example that takes into account the start and end dates of the interest rates:

```SAS
data balances;
  input date date9. balance;
  format date date9.;
  datalines;
01JAN2022 1000
02JAN2022 1050
03JAN2022 1100
; /* Add more data as needed */
run;

data interest_rates;
  input start_date date9. end_date date9. interest_rate;
  format start_date end_date date9.;
  datalines;
01JAN2022 02JAN2022 0.02
03JAN2022 05JAN2022 0.025
; /* Add more data as needed */
run;

data interest_comparison;
  merge balances interest_rates;
  by date;

  /* Check if the date is within the interest rate period */
  if start_date <= date <= end_date then do;
    /* Calculate interest with the original rate */
    original_interest = balance * interest_rate;

    /* Calculate interest with the new rate (adjust as needed) */
    new_interest = balance * (interest_rate + 0.005); /* Example: Increase interest rate by 0.005 */

    /* Calculate the difference in interest */
    interest_difference = new_interest - original_interest;

    output;
  end;
run;

/* Print the new dataset */
proc print data=interest_comparison;
run;
```

In this example:

- I added a dataset named interest_rates that includes start and end dates for each interest rate.
- The merge statement is used to combine the balances and interest_rates datasets based on the common variable date.
- The if statement checks if the date is within the interest rate period. If so, it calculates the interest with the original rate, new rate, and the difference in interest.

Adjust the variable names and values in the calculation according to your specific dataset and requirements.

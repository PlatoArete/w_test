/* Sort both datasets */
proc sort data=celq_dates; 
   by cust delq_sdt delq_edt; 
run;

proc sort data=cint_dates; 
   by cust cint2_sdt; 
run;

/* Step 1: Create a cross join of cint start dates with delinquency periods by customer */
data work_cross;
   merge cint_dates(in=a) celq_dates(in=b);
   by cust;
   if a and b;
run;

/* Step 2: Filter to only relevant combinations */
data work_mapping;
   set work_cross;
   /* Include combinations where:
      - Delinquency starts on or after cint start date, OR
      - Delinquency period overlaps cint start date */
   if (delq_sdt >= cint2_sdt) or 
      (delq_sdt < cint2_sdt and delq_edt >= cint2_sdt) then output;
run;

/* Step 3: Sort for processing */
proc sort data=work_mapping;
   by cust cint2_sdt delq_sdt delq_edt;
run;

/* Step 4: Process to create continuous periods */
data cint_periods;
   set work_mapping;
   by cust cint2_sdt;
   
   /* Variables to track the current period */
   retain period_start period_end period_num;
   format period_start period_end date9.;
   
   /* Initialize for each customer */
   if first.cust then period_num = 0;
   
   /* Start a new period for each cint start date */
   if first.cint2_sdt then do;
      /* Check if this cint start date falls within the previous period */
      if period_num > 0 and cint2_sdt <= period_end then do;
         /* This cint start date is part of the previous period */
         /* Keep the existing period going, just update delq periods if needed */
         period_end = max(period_end, delq_edt + 60);
      end;
      else do;
         /* This is a new period */
         /* Output the previous period if it exists */
         if period_num > 0 then do;
            output;
         end;
         period_num + 1;
         period_start = cint2_sdt;
         period_end = delq_edt + 60;
      end;
   end;
   else do;
      /* Continue with the current period, checking for overlap */
      if delq_sdt <= period_end then do;
         /* This delinquency period overlaps with our current period */
         period_end = max(period_end, delq_edt + 60);
      end;
   end;
   
   /* Output the last period for each customer */
   if last.cust then do;
      output;
   end;
   
   /* Keep and rename relevant variables */
   keep cust period_start period_end period_num;
   rename period_start=cint2_sdt period_end=cint2_edt;
run;

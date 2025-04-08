/* Step 1: Transpose cint_dates to have all cint start dates as variables for each customer */
proc transpose data=cint_dates out=cint_wide prefix=cint_date;
   by cust;
   var cint2_sdt;
run;

/* Step 2: Join the transposed cint dates with delinquency periods */
data work_step2;
   merge cint_wide delq_dates;
   by cust;
   
   /* Find the most relevant cint start date for this delinquency period */
   relevant_cint_date = .;
   array cint_dates{*} cint_date:;
   
   do i = 1 to dim(cint_dates);
      if cint_dates[i] ne . and 
         cint_dates[i] <= delq_edt and
         (relevant_cint_date = . or cint_dates[i] > relevant_cint_date) then do;
         relevant_cint_date = cint_dates[i];
      end;
   end;
   
   /* Only keep records with a relevant cint date */
   if relevant_cint_date ne . then do;
      cint2_sdt = relevant_cint_date;
      keep cust delq_sdt delq_edt cint2_sdt;
      output;
   end;
   
   format cint2_sdt date9.;
run;

/* Step 3: Sort for processing */
proc sort data=work_step2;
   by cust cint2_sdt delq_sdt;
run;

/* Step 4: Create continuous periods */
data cint_periods;
   set work_step2;
   by cust;
   
   /* Track the current continuous period */
   retain period_start period_end;
   format period_start period_end date9.;
   
   /* Initialize for first record of each customer */
   if first.cust then do;
      period_start = cint2_sdt;
      period_end = delq_edt + 60;
   end;
   else do;
      /* Check if this record continues the current period */
      if delq_sdt <= period_end then do;
         /* Extend the current period if needed */
         period_end = max(period_end, delq_edt + 60);
      end;
      else do;
         /* Output the completed period and start a new one */
         cint2_sdt = period_start;
         cint2_edt = period_end;
         output;
         period_start = cint2_sdt;
         period_end = delq_edt + 60;
      end;
   end;
   
   /* Output the final period for each customer */
   if last.cust then do;
      cint2_sdt = period_start;
      cint2_edt = period_end;
      output;
   end;
   
   keep cust cint2_sdt cint2_edt;
run;

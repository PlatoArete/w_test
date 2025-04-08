/* Step 1: Sort both datasets */
proc sort data=celq_dates; 
   by cust delq_sdt delq_edt; 
run;

proc sort data=cint_dates; 
   by cust cint2_sdt; 
run;

/* Step 2: Create a working dataset that identifies which delinquency 
   periods are associated with which cint start dates */
data work_mapping;
   merge cint_dates(in=a) celq_dates(in=b);
   by cust;
   if a and b;
   
   /* Flag delinquency periods that overlap with or follow cint start dates */
   if delq_sdt >= cint2_sdt or 
      (delq_sdt < cint2_sdt and delq_edt >= cint2_sdt) then output;
run;

/* Step 3: Process each customer to identify continuous periods */
proc sort data=work_mapping;
   by cust cint2_sdt delq_sdt;
run;

data cint_final_periods;
   set work_mapping;
   by cust cint2_sdt;
   
   /* Track the current period */
   retain period_start period_end period_id 0;
   format period_start period_end date9.;
   
   /* Start a new period for each customer */
   if first.cust then period_id = 1;
   
   /* Start a new period if this is a new cint start date outside current period */
   if first.cint2_sdt then do;
      if _n_ > 1 and cint2_sdt > period_end + 60 then do;
         /* Output previous period */
         cint2_edt = period_end + 60;
         cint2_sdt = period_start;
         output;
         /* Start new period */
         period_id + 1;
         period_start = cint2_sdt;
         period_end = delq_edt;
      end;
      else if _n_ = 1 then do;
         /* First record */
         period_start = cint2_sdt;
         period_end = delq_edt;
      end;
      else do;
         /* Extend current period */
         period_end = max(period_end, delq_edt);
      end;
   end;
   else do;
      /* Check for overlapping delinquency periods */
      if delq_sdt <= period_end + 60 then do;
         period_end = max(period_end, delq_edt);
      end;
      else do;
         /* Output current period and start new one */
         cint2_edt = period_end + 60;
         cint2_sdt = period_start; 
         output;
         /* Start new period */
         period_id + 1;
         period_start = cint2_sdt;
         period_end = delq_edt;
      end;
   end;
   
   /* Output the last period for each customer */
   if last.cust then do;
      cint2_edt = period_end + 60;
      cint2_sdt = period_start;
      output;
   end;
   
   keep cust cint2_sdt cint2_edt period_id;
run;

/* Step 4: Remove duplicate periods */
proc sort data=cint_final_periods nodupkey;
   by cust period_id;
run;

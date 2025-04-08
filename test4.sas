/* Step 0: Ensure data is sorted by customer and potential period start date */
/* This helps in processing and identifying sequential periods */
PROC SORT DATA=have_data OUT=sorted_data;
    BY cdu_cin cint2_dt;
RUN;

/* Step 1: Identify unique potential period start dates for each customer */
/* NODUPKEY keeps the first record for each unique combination */
PROC SORT DATA=sorted_data(WHERE=(cint2_dt IS NOT NULL))
           OUT=potential_starts NODUPKEY;
    BY cdu_cin cint2_dt;
RUN;

/* Step 2: Create period windows */
/* For each period start, find the start date of the NEXT period */
DATA period_windows;
    /* Use RETAIN to hold the 'next' start date from the previous iteration */
    RETAIN next_cint2_dt .;

    /* Read potential start dates two at a time using SET and POINT= */
    /* This is a way to look ahead within a BY group */
    do point = 1 by 1 until(last_obs);
        set potential_starts point=point end=last_obs;
        by cdu_cin; /* Need BY group processing */

        /* Read the next observation to get the next start date */
        point_plus_1 = point + 1;
        set potential_starts (keep=cdu_cin cint2_dt rename=(cint2_dt=_next_dt cdu_cin=_next_cin)) point=point_plus_1;

        /* Check if the next record is for the same customer */
        if cdu_cin = _next_cin then do;
            next_cint2_dt = _next_dt;
        end;
        else do; /* Last period for this customer OR last record overall */
            next_cint2_dt = .; /* No subsequent start date */
        end;

        /* Assign period number */
        RETAIN period_num 0;
        if first.cdu_cin then period_num = 1;
        else period_num + 1;

        /* Define the boundary for the current period */
        period_start_cint2_dt = cint2_dt;
        if next_cint2_dt = . then
            /* If no next period, set boundary far in the future */
            period_end_boundary = '31DEC9999'd;
        else
            /* Boundary is strictly BEFORE the next period starts */
            period_end_boundary = next_cint2_dt;

        OUTPUT;

        /* Reset next_cin for safety if it was read beyond end of file */
         if point = lag(point) then _next_cin = .;
         /* Need a more robust lookahead, DATA step POINT= is tricky */
    end;
    stop; /* Stop processing after the DO loop */

    FORMAT period_start_cint2_dt period_end_boundary DATE9.;
    KEEP cdu_cin period_num period_start_cint2_dt period_end_boundary;
RUN;

/* ---- ALTERNATIVE and often MORE ROBUST Step 2 using LAG function ---- */
/* Requires data sorted by customer and start date */
DATA period_windows_lag;
    SET potential_starts;
    BY cdu_cin cint2_dt; /* Ensure correct sorting */

    /* Get the start date of the next record within the customer group */
    next_cint2_dt = LAG(cint2_dt); /* LAG gets previous, need LEAD. SAS doesn't have direct LEAD */
    /* Workaround for LEAD: Sort descending and use LAG, or use PROC EXPAND, or merge */

    /* --- Using Merge for LEAD --- */
    /* Create sequence number */
    DATA potential_starts_seq;
      SET potential_starts;
      BY cdu_cin;
      RETAIN _seq_;
      IF FIRST.cdu_cin THEN _seq_ = 1;
      ELSE _seq_ + 1;
    RUN;

    /* Merge current record (_seq_) with next record (_seq_+1) */
    DATA period_windows;
       MERGE potential_starts_seq(RENAME=(cint2_dt=period_start_cint2_dt _seq_=period_num)) /* Current */
             potential_starts_seq(FIRSTOBS=2 KEEP=cdu_cin cint2_dt _seq_
                                  RENAME=(cint2_dt=next_cint2_dt _seq_=_next_seq_)) /* Next record */
             ;
       BY cdu_cin; /* Needed for MERGE logic check */

       /* Check if the 'next' record belongs to the same customer */
       /* This condition effectively matches seq_num with (seq_num+1)-1 */
       IF period_num = _next_seq_ - 1;

       /* Define the end boundary for the period */
       IF next_cint2_dt = . THEN
           period_end_boundary = '31DEC9999'd; /* Last period for customer */
       ELSE
           period_end_boundary = next_cint2_dt; /* Ends before next period starts */

       FORMAT period_start_cint2_dt period_end_boundary DATE9.;
       KEEP cdu_cin period_num period_start_cint2_dt period_end_boundary;
    RUN;
/* ---- END OF ALTERNATIVE Step 2 ---- */


/* Step 3: Find the maximum delq_edt within each period window */
/* Join the original data (with all delq_edt) to the period windows */
PROC SQL NOPRINT;
   CREATE TABLE period_max_delq AS
   SELECT
      p.cdu_cin,
      p.period_num,
      MAX(d.delq_edt) AS period_latest_delq_edt /* Find max delq_edt in window */
   FROM
      period_windows AS p
   INNER JOIN
      sorted_data AS d ON p.cdu_cin = d.cdu_cin /* Join all customer records */
   WHERE
      d.delq_edt >= p.period_start_cint2_dt /* Delq ends ON OR AFTER period start */
      AND d.delq_edt < p.period_end_boundary   /* Delq ends BEFORE next period starts */
      AND d.delq_edt IS NOT NULL             /* Only consider non-missing dates */
   GROUP BY
      p.cdu_cin,
      p.period_num;
QUIT;

/* Step 4: Join the max delinquency date back to the period definitions */
/* Use LEFT JOIN to keep all periods, even those with no matching delq_edt */
PROC SQL;
   CREATE TABLE customer_final_periods AS
   SELECT
      pw.cdu_cin,
      pw.period_num,
      pw.period_start_cint2_dt,
      pmd.period_latest_delq_edt /* This will be missing if no delq_edt found in window */
   FROM
      period_windows AS pw
   LEFT JOIN
      period_max_delq AS pmd ON pw.cdu_cin = pmd.cdu_cin AND pw.period_num = pmd.period_num
   ORDER BY
      pw.cdu_cin,
      pw.period_num;
QUIT;

/* Step 5: Optional - View the final results */
PROC PRINT DATA=customer_final_periods NOOBS LABEL;
    TITLE "Customer Periods: Start Date and Latest Associated Delinquency End Date";
    LABEL period_start_cint2_dt = "Period Start (cint2_dt)"
          period_latest_delq_edt = "Latest Associated Delinquency End (delq_edt)"
          period_num = "Period Sequence";
    FORMAT period_start_cint2_dt period_latest_delq_edt DATE9.;
RUN;
TITLE; /* Clear title */

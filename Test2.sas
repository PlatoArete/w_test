/* Step 1: Sort both datasets by account and date */
proc sort data=charges;
   by account_id charge_date charge_amount;
run;

proc sort data=refunds;
   by account_id refund_date refund_amount;
run;

/* Step 2: Create unique IDs for charges and refunds separately */
data charges_with_id;
   set charges;
   by account_id charge_date charge_amount;
   if first.account_id then charge_id = 0;
   charge_id + 1; /* Increment for every charge record */
run;

data refunds_with_id;
   set refunds;
   by account_id refund_date refund_amount;
   if first.account_id then refund_id = 0;
   refund_id + 1; /* Increment for every refund record */
run;

/* Step 3: Create all possible charge-refund pairs within the same account */
proc sql;
   create table all_pairs as
   select a.account_id, a.charge_id, a.charge_date, a.charge_amount,
          b.refund_id, b.refund_date, b.refund_amount,
          calculated refund_date - calculated charge_date as days_between
   from charges_with_id as a, refunds_with_id as b
   where a.account_id = b.account_id
         and a.charge_amount = b.refund_amount
         and calculated days_between >= 0
   order by a.account_id, calculated days_between, a.charge_id, b.refund_id;
quit;

/* Step 4: Use a greedy approach to match each refund to nearest charge */
data matched_pairs;
   set all_pairs;
   by account_id days_between;
   
   /* Use retain to track which charges and refunds have been matched */
   retain matched_charges matched_refunds;
   array matched_c{1000} $ 1 _temporary_;
   array matched_r{1000} $ 1 _temporary_;
   
   /* Initialize arrays at the start of each account */
   if first.account_id then do;
      do i = 1 to 1000;
         matched_c{i} = '';
         matched_r{i} = '';
      end;
   end;
   
   /* Check if this charge or refund has already been matched */
   if matched_c{charge_id} = '' and matched_r{refund_id} = '' then do;
      /* Neither has been matched yet, so create a match */
      matched_c{charge_id} = 'Y';
      matched_r{refund_id} = 'Y';
      match_status = 'Matched';
      output; /* Output this match */
   end;
run;

/* Step 4: Use a greedy approach with hash objects to match refunds to charges */
data matched_pairs;
   set all_pairs;
   by account_id days_between;
   
   /* Declare hash objects to track matched charges and refunds */
   if _N_ = 1 then do;
      declare hash matched_charges();
      matched_charges.definekey('account_id', 'charge_id');
      matched_charges.definedone();
      
      declare hash matched_refunds();
      matched_refunds.definekey('account_id', 'refund_id');
      matched_refunds.definedone();
   end;
   
   /* Check if this charge or refund has already been matched */
   if matched_charges.find(key: account_id, key: charge_id) ne 0 and
      matched_refunds.find(key: account_id, key: refund_id) ne 0 then do;
      /* Neither has been matched yet, so create a match */
      matched_charges.add(key: account_id, key: charge_id);
      matched_refunds.add(key: account_id, key: refund_id);
      match_status = 'Matched';
      output; /* Output this match */
   end;
run;

/* Step 5: Identify all the charges that have been matched */
proc sql;
   create table matched_charge_ids as
   select distinct account_id, charge_id
   from matched_pairs;
quit;

/* Step 6: Get all unmatched charges and add them to the final dataset */
proc sql;
   create table unmatched_charges as
   select a.account_id, a.charge_id, a.charge_date, a.charge_amount,
          . as refund_id, /* Null value for refund_id */
          . as refund_date format=date9., /* Null value for refund_date */
          . as refund_amount, /* Null value for refund_amount */
          . as days_between, /* Null value for days_between */
          'Unmatched' as match_status
   from charges_with_id a
   where not exists (
      select 1
      from matched_charge_ids b
      where a.account_id = b.account_id
      and a.charge_id = b.charge_id
   );
quit;

/* Step 7: Combine matched pairs and unmatched charges */
data final_results;
   set matched_pairs unmatched_charges;
   by account_id;
run;

/* Sort the final results for better readability */
proc sort data=final_results;
   by account_id charge_date refund_date;
run;

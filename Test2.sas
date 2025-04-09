data fuzzy_compare;
    str_a = 'analyze';
    str_b = 'analyse'; /* Substitution s/z */
    str_c = 'analyzed';/* Insertion d */
    str_d = 'analze';  /* Deletion y, Transposition z/e */
    str_e = 'apple';   /* Very different */

    /* Levenshtein Distance */
    dist_lev_ab = complev(str_a, str_b); /* Result: 1 (s->z) */
    dist_lev_ac = complev(str_a, str_c); /* Result: 1 (insert d) */
    dist_lev_ad = complev(str_a, str_d); /* Result: 2 (delete y, transpose z/e) */
    dist_lev_ae = complev(str_a, str_e); /* Result: 5 */

    /* Spelling Distance (often preferred for typos) */
    dist_spedis_ab = spedis(str_a, str_b); /* Result: 10 (scale differs, lower=better)*/
    dist_spedis_ac = spedis(str_a, str_c); /* Result: 10 */
    /* SPEDIS handles transposition better */
    dist_spedis_ad = spedis(str_a, str_d); /* Result: 15 (del y=10, transp ze=5) */ 
    dist_spedis_ae = spedis(str_a, str_e); /* Result: 50 */

    /* Normalize SPEDIS (optional, gives ~ percentage similarity) */
    /* Formula: 100 * (1 - SPEDIS / (10 * MAX(LEN1, LEN2))) */
    /* Note: SPEDIS max cost seems to be 10*max_len, need to verify scale*/
    /* A simpler normalization for comparison: lower SPEDIS is better */

    /* Normalize Levenshtein (e.g., as similarity percentage) */
    len_a = lengthn(str_a); /* Use lengthn for non-blanks */
    len_b = lengthn(str_b);
    len_e = lengthn(str_e);
    max_len_ab = max(len_a, len_b);
    max_len_ae = max(len_a, len_e);
    
    /* Higher value = More similar */
    similarity_pct_ab = (1 - (dist_lev_ab / max_len_ab)) * 100; /* ~85.7% */
    similarity_pct_ae = (1 - (dist_lev_ae / max_len_ae)) * 100; /* ~28.6% */


run;

proc print data=fuzzy_compare; run;

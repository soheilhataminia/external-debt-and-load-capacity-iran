'==========================================================
'  REPLICATION SCRIPT  –  External Debt & Load Capacity
'  Data:  Iran 1995-2023  (clean_dataset_1995_2023.xlsx)
'==========================================================

'--------------- 1. CREATE ANNUAL WORKFILE ----------------
wf create a 1995 2023

'--------------- 2. IMPORT DATA ---------------------------
import "clean_dataset_1995_2023.xlsx" range="Sheet1!A1:F30" @freq a @date @colheader 1 @bycol 1

' The series now in memory:  CF  ED  EGDP  NNR  REC

'--------------- 3. TRANSFORMATIONS -----------------------
series lcf   = log(CF)
series led   = log(ED)
series legdp = log(EGDP + 100)      ' shift to remove negative/zero values
series lnnr  = log(NNR)
series lrec  = log(REC)

'--------------- 4. DESCRIPTIVE STATISTICS ---------------
freeze(tbl_desc) stats lcf led legdp lnnr lrec
tbl_desc.save(t=rtf) tbl_desc.rtf

'--------------- 5. UNIT-ROOT TESTS  ----------------------
for %s lcf led legdp lnnr lrec
  freeze(adf_%s_lvl) %s.adf c 0      ' ADF at level (no trend, 0 lags)
  freeze(adf_%s_d1 ) d(%s).adf c 0   ' ADF at first difference
next
' (add PP or ZA tests here if needed)

'--------------- 6. LAG-LENGTH SELECTION ------------------
var tmp_var.ls 1 3 lcf led legdp lnnr lrec
tmp_var.laglen(aic sbc hq)

' Assume optimal lag = 1 based on the criteria.
scalar optlag = 1

'--------------- 7. JOHANSEN COINTEGRATION ---------------
coint(output=ct) johansen optlag lcf led legdp lnnr lrec @trend(c)

'--------------- 8. FMOLS LONG-RUN ESTIMATION ------------
equation eq_fm.fmols(l, truncate=1) lcf c led legdp lnnr lrec
eq_fm.save(t=rtf) fmols_results.rtf

'--------------- 9. DIAGNOSTIC TESTS ----------------------
' 9.1 Normality (Jarque–Bera)
series u = eq_fm.resid
freeze(jb) u.jb
' 9.2 Serial correlation (Breusch–Godfrey, lag 12)
freeze(bg) u.bgtest(12)
' 9.3 Heteroskedasticity (White)
freeze(white) u.whitetest
' 9.4 Specification (Ramsey RESET, order 2)
freeze(reset) eq_fm.reset(2)
' 9.5 Ljung–Box Q and ARCH-LM (lag 12)
freeze(qstat) u.lbq(12)
freeze(arch)  u.archtest(12)

'--------------- 10. ERROR-CORRECTION MODEL ---------------
series ec = eq_fm.resid
equation eq_ecm.ls d(lcf) c d(led) d(legdp) d(lnnr) d(lrec) ec(-1)
eq_ecm.save(t=rtf) ecm_results.rtf

'--------------- 11. EXPORT ALL OUTPUT -------------------
pageoutput(page=output) save "replication_output.rtf"

'=============== END OF SCRIPT ============================

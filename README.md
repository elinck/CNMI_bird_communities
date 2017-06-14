# Analysis of Mariana Islands bird survey data

Repository for analysis of point transect bird survey data on Saipan, Tinian, and Rota associated with the following manuscript in preparation:  
  
Linck, E., Fricke, E., Rogers, S. In prep. Varied abundance and functional diversity in the surviving bird communities of the Mariana Islands  
  
### Code  
**Script:** `marianas_survey_analysis.R`  
**Description:** Cleans data, generates unbiased density estimates and other population indices, produces plots  
**Notes:** `unmarked` analysis can be commented out and results loaded from CNMI_bird_communities/data/ instead  
  
### Data  
**File:** `fulldata.text`  
**Description:** Tab-delimited raw point count data  
**Notes:** Shorthand species IDs are first two letters of genus and species  
  
**File:** `FD_matrix.csv`  
**Description:**  Functional trait values for all species  
  
**Files:**  `lambda.*.out.*.csv`  
**Description:** Primary unmarked output for density estimates. Copies with `.*island*.` and / or `.*allspp*.` indicate version where 
estimates are island (versus site) specific, and where all species are included regardless of minimum individual threshhold. 
  
**Files:**  `det.*.out.*.csv`   
**Description:** Additional unmarked output for density estimates Copies with `.*island*.` and / or `.*allspp*.` indicate version where 
estimates are island (versus site) specific, and where all species are included regardless of minimum individual threshhold. 
  
**Files:** `phi.*.out.*.csv`   
**Description:** Additional unmarked output for density estimates. Copies with `.*island*.` and / or `.*allspp*.` indicate version where 
estimates are island (versus site) specific, and where all species are included regardless of minimum individual threshhold.   
  

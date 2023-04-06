/****** Script for SelectTopNRows command from SSMS  ******/
IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion') IS NOT NULL DROP TABLE NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion
--This table provides the latest Sub ICB Codes (which currently are the same as 2021 CCG Codes) and provides the Sub ICB Name, ICB and Region names and codes for that Sub ICB code
--It contains 106 rows for the 106 Sub ICBs
SELECT DISTINCT 
	[Organisation_Code] AS 'Sub ICB Code'
	,[Organisation_Name] AS 'Sub ICB Name' 
    ,[STP_Code] AS 'ICB Code'
	,[STP_Name] AS 'ICB Name'
	,[Region_Code] AS 'Region Code' 
	,[Region_Name] AS 'Region Name'
--INTO creates this table
INTO NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion
FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
--Effective_To has the date the Org Code is applicable to so the codes currently in use have null in this column.
--Filtering for just clinical commissioning group org type - this means commissioning hubs are excluded
WHERE [Effective_To] IS NULL AND [NHSE_Organisation_Type]='CLINICAL COMMISSIONING GROUP'


--Combines the two data collections for dementia into one place
IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData]
SELECT * 
INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsychoticData_SubICB]

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData]
SELECT *
FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsychoticData_SubICB_Primary_Care_Collection]

------------------------------------------------------------------------------------Sub ICBs--------------------------------------------------------------------
--Deletes temporary table if it exists so it can be written into
IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.TEMP_DEM_AntiPsyStep1') IS NOT NULL DROP TABLE NHSE_Sandbox_MentalHealth.dbo.TEMP_DEM_AntiPsyStep1

SELECT *
INTO NHSE_Sandbox_MentalHealth.dbo.TEMP_DEM_AntiPsyStep1
FROM(
-----------------------------------Sub ICBs (recalculated based on introduction of ICBs and sub ICBs in July 2022)----------------------------------------------------------------------------------------
SELECT
     --MAX is used on the columns which aren't included in the group by statement at the end and which don't use the sum function
    z.[Month]
	--CAST AS FLOAT used to remove the excess 0s
	--Summing the measures grouped by the month, the CCG21 code and name in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
	--Calculating the proportions for the CCG21 codes
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'Sub ICB' AS [Org Type]
	,b.[Sub ICB Code] AS [Org Code]
    ,b.[Sub ICB Name] AS [Org Name]
	,MAX(b.[ICB Code]) AS [ICB Code]
	,MAX(b.[ICB Name]) AS [ICB Name]
	,MAX(b.[Region Name]) AS [Region Name]
	,MAX(b.[Region Code]) AS [Region Code]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData] z
--Joins to the CCG lookup table to match the old CCG codes with the 2021 codes. 
--LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_GPPractice] c ON c.GP_Practice_Code COLLATE DATABASE_DEFAULT=Practice_Code
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] a ON z.Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the CCGtoRegionSBG temp table which has the CCG21 codes, CCG names and matches to STP codes, STP names and Region codes and Region names
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion b ON a.CCG21 = b.[Sub ICB Code]
--Only join on CCGs - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want CCG
WHERE [Type]='CCG' OR [Type]='SUB_ICB_LOC'
--This relates to the summing of register and estimate to recalculate these based on CCG21 code and name and the effective snapshot date
GROUP BY [Sub ICB Code], [Sub ICB Name], [Month]


UNION


-----------------------------------------------------ICBs---------------------------------------------
SELECT
     --MAX is used on the columns which aren't included in the group by statement at the end and which don't use the sum function
    z.[Month]
	--CAST AS FLOAT used to remove the excess 0s
	--Summing the measures grouped by the month, the CCG21 code and name in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
	--Calculating the proportions for the CCG21 codes
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'ICB' AS [Org Type]
	,b.[ICB Code] AS [Org Code]
    ,b.[ICB Name] AS [Org Name]
	,MAX(b.[ICB Code]) AS [ICB Code]
	,MAX(b.[ICB Name]) AS [ICB Name]
	,MAX(b.[Region Name]) AS [Region Name]
	,MAX(b.[Region Code]) AS [Region Code]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData] z
--Joins to the CCG lookup table to match the old CCG codes with the 2021 codes. 
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] a ON z.Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the CCGtoRegionSBG temp table which has the CCG21 codes, CCG names and matches to STP codes, STP names and Region codes and Region names
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion b ON a.CCG21 = b.[Sub ICB Code]
--Only join on CCGs - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want CCG
WHERE [Type]='CCG' OR [Type]='SUB_ICB_LOC'
--This relates to the summing of register and estimate to recalculate these based on CCG21 code and name and the effective snapshot date
GROUP BY [ICB Code], [ICB Name], [Month]

UNION

-----------------------------------------------------------------Regions----------------------------

SELECT
     --MAX is used on the columns which aren't included in the group by statement at the end and which don't use the sum function
    z.[Month]
	--CAST AS FLOAT used to remove the excess 0s
	--Summing the measures grouped by the month, the CCG21 code and name in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
	--Calculating the proportions for the CCG21 codes
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'Region' AS [Org Type]
	,b.[Region Code] AS [Org Code]
    ,b.[Region Name] AS [Org Name]
	,MAX(b.[ICB Code]) AS [ICB Code]
	,MAX(b.[ICB Name]) AS [ICB Name]
	,MAX(b.[Region Name]) AS [Region Name]
	,MAX(b.[Region Code]) AS [Region Code]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData] z
--Joins to the CCG lookup table to match the old CCG codes with the 2021 codes. 
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] a ON z.Code= a.IC_CCG COLLATE DATABASE_DEFAULT
--Joins to the CCGtoRegionSBG temp table which has the CCG21 codes, CCG names and matches to STP codes, STP names and Region codes and Region names
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion b ON a.CCG21 = b.[Sub ICB Code]
--Only join on CCGs - the UKHF data has all geography types in the column Org_Type i.e. Region, STP, CCG and we only want CCG
WHERE [Type]='CCG' OR [Type]='SUB_ICB_LOC'
--This relates to the summing of register and estimate to recalculate these based on CCG21 code and name and the effective snapshot date
GROUP BY [Region Code], [Region Name], [Month]

UNION
---------------------------------------------------------National---------------------------------------------------------

SELECT
     --MAX is used on the columns which aren't included in the group by statement at the end and which don't use the sum function
    z.[Month]
	--CAST AS FLOAT used to remove the excess 0s
	--Summing the measures grouped by the month, the CCG21 code and name in order to recalculate these for any mergers/splits that have occurred
    ,SUM(CAST(z.[Without Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[With Psychosis Diagnosis] AS FLOAT)) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,SUM(CAST(z.[Dementia Register] AS FLOAT)) AS [DEM_REGISTER]
	--Calculating the proportions for the CCG21 codes
	,(SUM(z.[Without Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
	,(SUM(z.[With Psychosis Diagnosis])/SUM(z.[Dementia Register])) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,'National' AS [Org Type]
	,'England' AS [Org Code]
    ,'England' AS [Org Name]
	,null AS [ICB Code]
	,null AS [ICB Name]
	,null AS [Region Name]
	,null AS [Region Code]
FROM [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData] z
WHERE [Type]='National'
--This relates to the summing of register and estimate to recalculate these based on CCG21 code and name and the effective snapshot date
GROUP BY  [Month])_


IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsy]') IS NOT NULL DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsy]

SELECT *
INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dementia_AntiPsy]
FROM(

SELECT
	MAX(b.[Org Type]) AS [Org Type]
	,MAX(b.[Org Name]) AS [Org Name]
	,b.[Org Code]
	,MAX(b.[ICB Name]) AS [ICB Name]
	,MAX(b.[Region Name]) AS [Region Name]
	,MAX([pbar]) AS [pbar]
	,MAX([pbar2]) AS [pbar2]
	--,MAX([nbar2]) AS [nbar2]
	,MAX([pbar]+(3*SQRT([pbar]*(1-[pbar])/(DEM_REGISTER)))) AS [UCL]
	,MAX([pbar]-(3*SQRT([pbar]*(1-[pbar])/(DEM_REGISTER)))) AS [LCL]
	,MAX([pbar2]+(3*SQRT([pbar2]*(1-[pbar2])/(DEM_REGISTER)))) AS [UCL2]
	,MAX([pbar2]-(3*SQRT([pbar2]*(1-[pbar2])/(DEM_REGISTER)))) AS [LCL2]
	,CAST(a.[Month] AS Date) AS [Effective_Snapshot_Date]
	,MAX(a.[ANTI_PSY_NO_PSY_DIAG_ALL_AGES]) AS [ANTI_PSY_NO_PSY_DIAG_ALL_AGES]
	,MAX(a.[ANTI_PSY_PSY_DIAG_ALL_AGES]) AS [ANTI_PSY_PSY_DIAG_ALL_AGES]
	,MAX(a.DEM_REGISTER) AS [DEM_REGISTER]
	,MAX(a.[Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_PSY_DIAG]
	,MAX(a.[Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]) AS [Proportion_of_DEM_WITH_ANTI_PSY_AND_NO_PSY_DIAG]
FROM(
SELECT
	MAX([Org Type]) AS [Org Type]
	,MAX([Org Name]) AS [Org Name]
	,[Org Code]
	,MAX([ICB Name]) AS [ICB Name]
	,MAX([Region Name]) AS [Region Name]
	--,(SUM([DEMENTIA_REGISTER_65_PLUS])/COUNT([Effective_Snapshot_Date]))AS [nbar2]
	,SUM([ANTI_PSY_NO_PSY_DIAG_ALL_AGES])/(SUM(DEM_REGISTER)) AS [pbar]
	,SUM([ANTI_PSY_PSY_DIAG_ALL_AGES])/(SUM(DEM_REGISTER)) AS [pbar2]
FROM NHSE_Sandbox_MentalHealth.dbo.TEMP_DEM_AntiPsyStep1
GROUP BY [Org Code]) AS b
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.TEMP_DEM_AntiPsyStep1 a ON b.[Org Code] = a.[Org Code]
GROUP BY b.[Org Code], CAST(a.[Month] AS Date))_


DROP TABLE NHSE_Sandbox_MentalHealth.dbo.TEMP_SubICBtoRegion
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[TEMP_DEM_AntiPsychoticData]
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.TEMP_DEM_AntiPsyStep1
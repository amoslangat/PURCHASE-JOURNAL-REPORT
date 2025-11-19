create or replace PACKAGE BODY      XXCA_PAY_HOUSING_LEVY_RPT_PKG
AS
     -------------------------------------------------------------------------------------
   --    Owner        : Communications Authority of Kenya
   --    Application  : XXCA
   --    Program Type : Package Specification
   --    File Name    : XXCA_PAY_HOUSING_LEVY_RPT_PKG.pks
   --    Date         : 23-AUGUST-2023 
   --    Author       : Sudhakrishna.Kanisetty
   --    Description  : This package will be used to fetch CA Payroll Housing leavy Info of employees,contractors,boardmembers,intrens
   --
   --
   --    Version      : 1.0
   --
   --    Modification History :
   --
   --    Who                          Date              Reason
   --    -------------             ----------         ---------------
   --    Sudhakrishna              23-AUGUST-2023        Initial Version 1.0
   -------------------------------------------------------------------------------------

-- Whenever this package is changed the following version number has to be updated

  g_version                  CONSTANT VARCHAR2(10)   := '1.0';
  g_package                  CONSTANT VARCHAR2(30)   := 'XXCA_PAY_HOUSING_LEVY_RPT_PKG';
  g_request_id               CONSTANT NUMBER(12)     := FND_GLOBAL.CONC_REQUEST_ID;
  g_business_group_id        CONSTANT NUMBER         := HR_GENERAL.GET_BUSINESS_GROUP_ID;
  g_session_id               CONSTANT NUMBER         := USERENV('SESSIONID');
  g_language                 CONSTANT VARCHAR2(10)   := USERENV('LANG');
  g_territory                CONSTANT VARCHAR2(100)  := FND_GLOBAL.NLS_TERRITORY;
  g_user_name                CONSTANT VARCHAR2(30)   := FND_GLOBAL.USER_NAME;
  g_user_id                  CONSTANT NUMBER         := FND_GLOBAL.USER_ID;
  g_sep                      CONSTANT VARCHAR2(1)    := ',';
  g_dq                       CONSTANT VARCHAR2(1)    := '"';
  g_newline                  CONSTANT VARCHAR2(10)   := '
'; -- CHR(13)
  g_divider                  CONSTANT VARCHAR2(200)  := '--------------------------------------------------------------------------------------';
  g_date_format              CONSTANT VARCHAR2(20)   := 'DD-MON-YYYY';
  g_null                     CONSTANT VARCHAR2(1)    := '';
  g_database_name            VARCHAR2(9);
  g_run_date                 CONSTANT DATE           := TRUNC(sysdate);
  g_run_date_time            CONSTANT DATE           := sysdate;

  g_errbuf                   VARCHAR2(4000) := '';
  e_error                    EXCEPTION;
  e_warning                  EXCEPTION;

-- function submit_bursting_prg(p_request_id IN number) RETURN BOOLEAN AS
--
--l_req_id          NUMBER;
--l_user_id         NUMBER;
--l_resp_id         NUMBER;
--l_resp_appl_id    NUMBER;
--err               VARCHAR2(4000);
--
--  BEGIN
--
--
--BEGIN 
--	select fnd.user_id , 
--       fresp.responsibility_id, 
--       fresp.application_id
-- INTO l_user_id,l_resp_id,l_resp_appl_id
--from   fnd_user fnd 
--,      fnd_responsibility_tl fresp 
--where  fnd.user_name = 'SYSADMIN'
--and    fresp.responsibility_name LIKE 'CA HRMS Manager';
--EXCEPTION
--  WHEN OTHERS THEN 
--  l_user_id := 0;
--  l_resp_id := 50738;
--  l_resp_appl_id :=200 ;
--
--	END;
--
--	fnd_global.APPS_INITIALIZE(user_id=>l_user_id, 
--                           resp_id=>l_resp_id, 
--                           resp_appl_id=>l_resp_appl_id);
--
--
--    l_req_id := fnd_request.submit_request(application => 'XDO',
--
--                                           program     => 'XDOBURSTREP',
--
--                                          description => '',
--
--                                           start_time  => '',
--
--                                           sub_request => FALSE,
--
--                                           argument1   => p_request_id,
--
--                                         argument2   => 'N');
--
--    commit;
--
--    IF l_req_id = 0 THEN
--
--      return false;
--
--    END IF;
--
--    return true;
--
--  exception
--
--    when others then
--
--     err := sqlerrm;
--
--     return false;
--
--  END submit_bursting_prg;

  FUNCTION replace_unwanted_characters ( p_string  IN  VARCHAR2 )
       RETURN VARCHAR2
   IS

       lc_return_string  VARCHAR2 ( 32767 );
       lc_replace_with   VARCHAR2 ( 1 );

   BEGIN

     lc_return_string  :=  REPLACE(REPLACE(REPLACE(REGEXP_REPLACE ( REGEXP_REPLACE ( p_string
                                                           , '[^[:alnum:]''+?.)(/-]'
                                                           , ' '
                                                           )
                                          , '( ){2,}'
                                          , ' '
                                          ),'-',''),'(',''),')','');

    -- lc_return_string  :=  UPPER ( lc_return_string );

     RETURN ( lc_return_string );

   END replace_unwanted_characters;


--
----------------------------------------------------------------------
-- FUNCTION: out
--
--   Procedure to print a message to the concurrent request out
----------------------------------------------------------------------
PROCEDURE out (p_message IN VARCHAR2) IS

BEGIN
  fnd_file.put_line (fnd_file.output, p_message);
EXCEPTION
  WHEN others THEN
    RAISE e_error;
END out;

--
----------------------------------------------------------------------
-- FUNCTION: log
--
--   Procedure to print a message to the concurrent request log
----------------------------------------------------------------------
PROCEDURE log (p_message          IN VARCHAR2) IS

BEGIN
  APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, TO_CHAR(sysdate, 'DD-MON-YYYY HH24:MI:SS') || ' '||p_message);
EXCEPTION
  WHEN others THEN
    RAISE e_error;
END log;  



  PROCEDURE PAY_MAIN (
      ERRBUF                          OUT VARCHAR2,
      RETCODE                         OUT VARCHAR2,
      p_employee_type                IN VARCHAR2,
      p_effective_date               IN  VARCHAR2
      )
   AS
  g_request_id     NUMBER  := apps.fnd_global.conc_request_id;
  l_from_date            DATE;
  l_to_date            DATE;
  l_org_id                hr_operating_units.organization_id%TYPE;
  l_request_id NUMBER;
  l_as_of_date DATE;
      CURSOR cur_employee(c_pay_date VARCHAR2)
        IS
  SELECT ppf.national_identifier
     , ppf.full_name
     , ppf.office_number 
     , (SELECT DISTINCT 
NVL(SUM(TO_NUMBER(rrv1.result_value)),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Gross Earnings' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND ppf1.employee_number  =  ppf.employee_number)- NVL((SELECT SUM (RESULT_VALUE)
FROM (
SELECT  
           prv1.result_value
    FROM   Pay_Element_Types_F PET1,
           Pay_Input_Values_F PIV1,
           Pay_Run_Result_Values PRV1,
           Pay_Run_Results PRR1,
           Pay_assignment_actions PAA1,
           Pay_payroll_actions PPA1,
           Pay_balance_types pbt1,
           Pay_balance_feeds_f pbff1,
           Per_people_f ppf1,
           Per_assignments_f paf1,
           Per_grades gr1,
           Pay_all_payrolls_f paygr1
   WHERE       PRR1.Element_Type_ID = PET1.Element_Type_ID
           AND PRR1.STATUS IN ('P', 'PA')
           AND PIV1.Element_Type_ID = PET1.Element_Type_ID
           AND PRV1.Input_Value_ID = PIV1.Input_Value_ID
           AND PRV1.Run_Result_ID = PRR1.Run_Result_ID
           AND PRR1.Assignment_Action_ID = PAA1.Assignment_Action_ID
           AND PAA1.Payroll_Action_ID = PPA1.Payroll_Action_ID
           --AND (PAF.Person_ID = '&&1' OR '&&1' IS NULL)
           AND PBFF1.balance_type_id = PBT1.balance_type_id
           AND PIV1.input_value_id = PBFF1.input_value_id
           AND PIV1.Name IN ('Pay Value')
           --AND PPA.EFFECTIVE_DATE BETWEEN '&&3' AND '&&4'
           AND PPF1.PERSON_ID = PAF1.PERSON_ID
           AND SYSDATE BETWEEN ppf1.effective_start_date
                           AND  ppf1.effective_end_date
           AND paf1.effective_start_date =
                 (SELECT   MAX (effective_start_date)
                    FROM   per_assignments_f paf11
                   WHERE   paf1.assignment_id = paf11.assignment_id)
           AND PAA1.ASSIGNMENT_ID = PAF1.ASSIGNMENT_ID
           AND GR1.GRADE_ID = PAF1.GRADE_ID
           AND PAYGR1.PAYROLL_ID = PAF1.PAYROLL_ID
           AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
           AND pbt1.balance_name = 'CA Housing Fund Levy Gross Salary Exempt'
		   AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
           AND paf1.assignment_number = ppf.employee_number )
),0) CA_Gross_Earnings,
 (SELECT DISTINCT 
NVL(SUM(TO_NUMBER(rrv1.result_value)),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Basic Salary' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND ppf1.employee_number  =  ppf.employee_number) Basic_salary,
 (SELECT DISTINCT 
NVL(SUM(TO_NUMBER(rrv1.result_value)),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employee,
 (SELECT DISTINCT 
NVL(SUM(TO_NUMBER(rrv1.result_value)),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employer,
(SELECT DISTINCT 
NVL(SUM(TO_NUMBER(rrv1.result_value)),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number)+
 (SELECT DISTINCT 
NVL(SUM(TO_NUMBER(rrv1.result_value)),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_HOUS_TOTAL
FROM
per_people_x ppf
WHERE 1 = 1
AND ppf.employee_number  IN (SELECT  DISTINCT 
ppf.employee_number
FROM
per_people_x ppf,
per_assignments_x paf,
pay_assignment_actions pas ,
pay_payroll_actions ppa,
pay_run_results rr,
pay_run_result_values rrv,
pay_element_types_f ety,
pay_input_values_F I ,
PER_TIME_PERIODS TP
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf.person_id = paf.person_id
AND paf.assignment_id = pas.assignment_id
AND pas.assignment_action_id = rr.assignment_action_id
AND ppa.payroll_action_id = pas.payroll_action_id
AND rr.element_type_id = ety.element_type_id
AND i.element_type_id = ety.element_type_id
AND rrv.run_result_id = rr.run_result_id
AND rrv.input_value_id = i.input_value_id
and TP.TIME_PERIOD_ID = PPA.TIME_PERIOD_ID
AND i.name = 'Pay Value'
AND TO_CHAR(ppa.effective_date, 'MON-YYYY') = c_pay_date
AND ety.element_name = 'CA Housing Levy Employer'
AND SYSDATE BETWEEN ppf.effective_start_date AND ppf.effective_end_date
  AND SYSDATE BETWEEN paf.effective_start_date AND paf.effective_end_date
AND ppf.employee_number  like   '2%');



CURSOR cur_temp_satff(c_pay_date VARCHAR2)
    IS 
   SELECT ppf.national_identifier
     , ppf.full_name
     , ppf.office_number 
     , (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Gross Earnings' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND ppf1.employee_number  =  ppf.employee_number) - NVL((SELECT SUM (RESULT_VALUE)
FROM (
SELECT   paf1.assignment_number,
           ppf1.full_name,
           gr1.name grade,
           paygr1.payroll_name payroll,
           pbt1.balance_name,
           ppa1.effective_date,
           prv1.result_value
    FROM   Pay_Element_Types_F PET1,
           Pay_Input_Values_F PIV1,
           Pay_Run_Result_Values PRV1,
           Pay_Run_Results PRR1,
           Pay_assignment_actions PAA1,
           Pay_payroll_actions PPA1,
           Pay_balance_types pbt1,
           Pay_balance_feeds_f pbff1,
           Per_people_f ppf1,
           Per_assignments_f paf1,
           Per_grades gr1,
           Pay_all_payrolls_f paygr1
   WHERE       PRR1.Element_Type_ID = PET1.Element_Type_ID
           AND PRR1.STATUS IN ('P', 'PA')
           AND PIV1.Element_Type_ID = PET1.Element_Type_ID
           AND PRV1.Input_Value_ID = PIV1.Input_Value_ID
           AND PRV1.Run_Result_ID = PRR1.Run_Result_ID
           AND PRR1.Assignment_Action_ID = PAA1.Assignment_Action_ID
           AND PAA1.Payroll_Action_ID = PPA1.Payroll_Action_ID
           --AND (PAF.Person_ID = '&&1' OR '&&1' IS NULL)
           AND PBFF1.balance_type_id = PBT1.balance_type_id
           AND PIV1.input_value_id = PBFF1.input_value_id
           AND PIV1.Name IN ('Pay Value')
           --AND PPA.EFFECTIVE_DATE BETWEEN '&&3' AND '&&4'
           AND PPF1.PERSON_ID = PAF1.PERSON_ID
           AND SYSDATE BETWEEN ppf1.effective_start_date
                           AND  ppf1.effective_end_date
           AND paf1.effective_start_date =
                 (SELECT   MAX (effective_start_date)
                    FROM   per_assignments_f paf11
                   WHERE   paf1.assignment_id = paf11.assignment_id)
           AND PAA1.ASSIGNMENT_ID = PAF1.ASSIGNMENT_ID
           AND GR1.GRADE_ID = PAF1.GRADE_ID
           AND PAYGR1.PAYROLL_ID = PAF1.PAYROLL_ID
           AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
		   AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
           AND pbt1.balance_name = 'CA Housing Fund Levy Gross Salary Exempt'
           AND paf1.assignment_number = ppf.employee_number )
),0 )CA_Gross_Earnings,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Monthly Wages' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) Basic_salary,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 


AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
  
  
  
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employee,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employer,
(SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number)+
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_HOUS_TOTAL
FROM
per_people_x ppf
WHERE 1 = 1
AND ppf.employee_number  IN (SELECT  DISTINCT 
ppf.employee_number
FROM
per_people_x ppf,
per_assignments_x paf,
pay_assignment_actions pas ,
pay_payroll_actions ppa,
pay_run_results rr,
pay_run_result_values rrv,
pay_element_types_f ety,
pay_input_values_F I ,
PER_TIME_PERIODS TP
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf.person_id = paf.person_id
AND paf.assignment_id = pas.assignment_id
AND pas.assignment_action_id = rr.assignment_action_id
AND ppa.payroll_action_id = pas.payroll_action_id
AND rr.element_type_id = ety.element_type_id
AND i.element_type_id = ety.element_type_id
AND rrv.run_result_id = rr.run_result_id
AND rrv.input_value_id = i.input_value_id
and TP.TIME_PERIOD_ID = PPA.TIME_PERIOD_ID
AND i.name = 'Pay Value'
AND TO_CHAR(ppa.effective_date, 'MON-YYYY') = c_pay_date
AND ety.element_name = 'CA Housing Levy Employer'
AND SYSDATE BETWEEN ppf.effective_start_date AND ppf.effective_end_date
  AND SYSDATE BETWEEN paf.effective_start_date AND paf.effective_end_date
AND ppf.employee_number  like   '5%')
;


CURSOR cur_Board_Members(c_pay_date VARCHAR2)
    IS 
    SELECT ppf.national_identifier
     , ppf.full_name
     , ppf.office_number 
     , (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Gross Earnings' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Gross_Earnings,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'Board Sitting allowance' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND ppf1.employee_number  =  ppf.employee_number) Basic_salary,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employee,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employer,
(SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number)+
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_HOUS_TOTAL
FROM
per_people_x ppf
WHERE 1 = 1
AND ppf.employee_number  IN  (SELECT  DISTINCT 
ppf.employee_number
FROM
per_people_x ppf,
per_assignments_x paf,
pay_assignment_actions pas ,
pay_payroll_actions ppa,
pay_run_results rr,
pay_run_result_values rrv,
pay_element_types_f ety,
pay_input_values_F I ,
PER_TIME_PERIODS TP
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf.person_id = paf.person_id
AND paf.assignment_id = pas.assignment_id
AND pas.assignment_action_id = rr.assignment_action_id
AND ppa.payroll_action_id = pas.payroll_action_id
AND rr.element_type_id = ety.element_type_id
AND i.element_type_id = ety.element_type_id
AND rrv.run_result_id = rr.run_result_id
AND rrv.input_value_id = i.input_value_id
and TP.TIME_PERIOD_ID = PPA.TIME_PERIOD_ID
AND i.name = 'Pay Value'
AND TO_CHAR(ppa.effective_date, 'MON-YYYY') = c_pay_date
AND ety.element_name = 'CA Housing Levy Employer'
AND SYSDATE BETWEEN ppf.effective_start_date AND ppf.effective_end_date
  AND SYSDATE BETWEEN paf.effective_start_date AND paf.effective_end_date
AND ppf.employee_number  like   '4%');


CURSOR cur_Intern(c_pay_date VARCHAR2)
    IS 
SELECT ppf.national_identifier
     , ppf.full_name
     , ppf.office_number 
     , (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Gross Earnings' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) - NVL((SELECT SUM (RESULT_VALUE)
FROM (
SELECT   paf1.assignment_number,
           ppf1.full_name,
           gr1.name grade,
           paygr1.payroll_name payroll,
           pbt1.balance_name,
           ppa1.effective_date,
           prv1.result_value
    FROM   Pay_Element_Types_F PET1,
           Pay_Input_Values_F PIV1,
           Pay_Run_Result_Values PRV1,
           Pay_Run_Results PRR1,
           Pay_assignment_actions PAA1,
           Pay_payroll_actions PPA1,
           Pay_balance_types pbt1,
           Pay_balance_feeds_f pbff1,
           Per_people_f ppf1,
           Per_assignments_f paf1,
           Per_grades gr1,
           Pay_all_payrolls_f paygr1
   WHERE       PRR1.Element_Type_ID = PET1.Element_Type_ID
           AND PRR1.STATUS IN ('P', 'PA')
           AND PIV1.Element_Type_ID = PET1.Element_Type_ID
           AND PRV1.Input_Value_ID = PIV1.Input_Value_ID
           AND PRV1.Run_Result_ID = PRR1.Run_Result_ID
           AND PRR1.Assignment_Action_ID = PAA1.Assignment_Action_ID
           AND PAA1.Payroll_Action_ID = PPA1.Payroll_Action_ID
           --AND (PAF.Person_ID = '&&1' OR '&&1' IS NULL)
           AND PBFF1.balance_type_id = PBT1.balance_type_id
           AND PIV1.input_value_id = PBFF1.input_value_id
           AND PIV1.Name IN ('Pay Value')
           --AND PPA.EFFECTIVE_DATE BETWEEN '&&3' AND '&&4'
           AND PPF1.PERSON_ID = PAF1.PERSON_ID
           AND SYSDATE BETWEEN ppf1.effective_start_date
                           AND  ppf1.effective_end_date
           AND paf1.effective_start_date =
                 (SELECT   MAX (effective_start_date)
                    FROM   per_assignments_f paf11
                   WHERE   paf1.assignment_id = paf11.assignment_id)
           AND PAA1.ASSIGNMENT_ID = PAF1.ASSIGNMENT_ID
           AND GR1.GRADE_ID = PAF1.GRADE_ID
           AND PAYGR1.PAYROLL_ID = PAF1.PAYROLL_ID
           AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
		   AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
           AND pbt1.balance_name = 'CA Housing Fund Levy Gross Salary Exempt'
           AND paf1.assignment_number = ppf.employee_number )
),0 )CA_Gross_Earnings,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Internship Pay' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) Basic_salary,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employee,
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_Hous_Employer,
(SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Fund Levy Employee' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number)+
 (SELECT DISTINCT 
NVL(TO_NUMBER(rrv1.result_value),0) result_value
FROM
per_people_x ppf1,
per_assignments_x paf1,
pay_assignment_actions pas1 ,
pay_payroll_actions ppa1,
pay_run_results rr1,
pay_run_result_values rrv1,
pay_element_types_f ety1,
pay_input_values_F I1 ,
PER_TIME_PERIODS TP1
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf1.person_id = paf1.person_id
AND paf1.assignment_id = pas1.assignment_id
AND pas1.assignment_action_id = rr1.assignment_action_id
AND ppa1.payroll_action_id = pas1.payroll_action_id
AND rr1.element_type_id = ety1.element_type_id
AND i1.element_type_id = ety1.element_type_id
AND rrv1.run_result_id = rr1.run_result_id
AND rrv1.input_value_id = i1.input_value_id
and TP1.TIME_PERIOD_ID = PPA1.TIME_PERIOD_ID
AND i1.name = 'Pay Value'
AND ety1.element_name = 'CA Housing Levy Employer' 
AND SYSDATE BETWEEN ppf1.effective_start_date AND ppf1.effective_end_date
  AND SYSDATE BETWEEN paf1.effective_start_date AND paf1.effective_end_date
AND to_char(ppa1.effective_date, 'MON-YYYY')= c_pay_date
AND ppf1.employee_number  =  ppf.employee_number) CA_HOUS_TOTAL
FROM
per_people_x ppf
WHERE 1 = 1
AND ppf.employee_number  IN (SELECT  DISTINCT 
ppf.employee_number
FROM
per_people_x ppf,
per_assignments_x paf,
pay_assignment_actions pas ,
pay_payroll_actions ppa,
pay_run_results rr,
pay_run_result_values rrv,
pay_element_types_f ety,
pay_input_values_F I ,
PER_TIME_PERIODS TP
-- PER_POSITION_DEFINITIONS PD
-- PAY_INPUT_VALUES_F
WHERE ppf.person_id = paf.person_id
AND paf.assignment_id = pas.assignment_id
AND pas.assignment_action_id = rr.assignment_action_id
AND ppa.payroll_action_id = pas.payroll_action_id
AND rr.element_type_id = ety.element_type_id
AND i.element_type_id = ety.element_type_id
AND rrv.run_result_id = rr.run_result_id
AND rrv.input_value_id = i.input_value_id
and TP.TIME_PERIOD_ID = PPA.TIME_PERIOD_ID
AND i.name = 'Pay Value'
AND TO_CHAR(ppa.effective_date, 'MON-YYYY')= c_pay_date
AND SYSDATE BETWEEN ppf.effective_start_date AND ppf.effective_end_date
  AND SYSDATE BETWEEN paf.effective_start_date AND paf.effective_end_date
AND ety.element_name = 'CA Housing Levy Employer'
AND ppf.employee_number  like   '6%')
;
      BEGIN

  log('Start procedure:  ' || 'pay_main');
  log(g_divider);
  log('CA Monthly Payroll Housing Fund Levy Report');
  log(g_divider);
  log('p_run_date:                     ' || g_run_date);
  log(g_divider);
  log('Parameters');
  log('Person Type    '||p_employee_type);
  log('Effective Date '||p_effective_date);
  log(g_divider);


 l_as_of_date := fnd_date.canonical_to_date (p_effective_date);



out( '<?xml version="1.0" encoding="UTF-8"?>') ;
        out( '<PAYHOSSINGLEVY>');
    out( '<LIST_PAYHOSSINGLEVY>');

    IF p_employee_type = 'Employee'
    THEN 
         FOR record_employee IN cur_employee(TO_CHAR(l_as_of_date, 'MON-RRRR'))
            LOOP
            out( '<G_PAYHOSSINGLEVY>');	  
            out( '<NATIONAL_IDENTIFIER>' || record_employee.NATIONAL_IDENTIFIER || '</NATIONAL_IDENTIFIER>');
            out( '<FULL_NAME>' || record_employee.FULL_NAME || '</FULL_NAME>');
            out( '<OFFICE_NUMBER>' || record_employee.OFFICE_NUMBER || '</OFFICE_NUMBER>');
            out( '<CA_GROSS_EARNINGS>' || record_employee.CA_GROSS_EARNINGS || '</CA_GROSS_EARNINGS>');
            out( '<BASIC_SALARY>' || record_employee.BASIC_SALARY || '</BASIC_SALARY>');
            out( '<CA_HOUS_EMPLOYEE>' || record_employee.CA_HOUS_EMPLOYEE || '</CA_HOUS_EMPLOYEE>');
            out( '<CA_HOUS_EMPLOYER>' || record_employee.CA_HOUS_EMPLOYER || '</CA_HOUS_EMPLOYER>');
            out( '<CA_HOUS_TOTAL>' || record_employee.CA_HOUS_TOTAL || '</CA_HOUS_TOTAL>');
            out( '</G_PAYHOSSINGLEVY>');
                END LOOP;
   END IF;
   IF p_employee_type = 'Temporary Staff'
    THEN 
         FOR record_temp_satff IN cur_temp_satff(TO_CHAR(l_as_of_date, 'MON-RRRR'))
            LOOP
            out( '<G_PAYHOSSINGLEVY>');	  
            out( '<NATIONAL_IDENTIFIER>' || record_temp_satff.NATIONAL_IDENTIFIER || '</NATIONAL_IDENTIFIER>');
            out( '<FULL_NAME>' || record_temp_satff.FULL_NAME || '</FULL_NAME>');
            out( '<OFFICE_NUMBER>' || record_temp_satff.OFFICE_NUMBER || '</OFFICE_NUMBER>');
            out( '<CA_GROSS_EARNINGS>' || record_temp_satff.CA_GROSS_EARNINGS || '</CA_GROSS_EARNINGS>');
            out( '<BASIC_SALARY>' || record_temp_satff.BASIC_SALARY || '</BASIC_SALARY>');
            out( '<CA_HOUS_EMPLOYEE>' || record_temp_satff.CA_HOUS_EMPLOYEE || '</CA_HOUS_EMPLOYEE>');
            out( '<CA_HOUS_EMPLOYER>' || record_temp_satff.CA_HOUS_EMPLOYER || '</CA_HOUS_EMPLOYER>');
            out( '<CA_HOUS_TOTAL>' || record_temp_satff.CA_HOUS_TOTAL || '</CA_HOUS_TOTAL>');
            out( '</G_PAYHOSSINGLEVY>');
                END LOOP;
   END IF;
    IF p_employee_type = 'Board Member'
    THEN 
         FOR record_Board_Members IN cur_Board_Members(TO_CHAR(l_as_of_date, 'MON-RRRR'))
            LOOP
            out( '<G_PAYHOSSINGLEVY>');	  
            out( '<NATIONAL_IDENTIFIER>' || record_Board_Members.NATIONAL_IDENTIFIER || '</NATIONAL_IDENTIFIER>');
            out( '<FULL_NAME>' ||           record_Board_Members.FULL_NAME || '</FULL_NAME>');
            out( '<OFFICE_NUMBER>' ||       record_Board_Members.OFFICE_NUMBER || '</OFFICE_NUMBER>');
            out( '<CA_GROSS_EARNINGS>' || record_Board_Members.CA_GROSS_EARNINGS || '</CA_GROSS_EARNINGS>');
            out( '<BASIC_SALARY>' ||        record_Board_Members.BASIC_SALARY || '</BASIC_SALARY>');
            out( '<CA_HOUS_EMPLOYEE>' ||    record_Board_Members.CA_HOUS_EMPLOYEE || '</CA_HOUS_EMPLOYEE>');
            out( '<CA_HOUS_EMPLOYER>' ||    record_Board_Members.CA_HOUS_EMPLOYER || '</CA_HOUS_EMPLOYER>');
            out( '<CA_HOUS_TOTAL>' ||       record_Board_Members.CA_HOUS_TOTAL || '</CA_HOUS_TOTAL>');
            out( '</G_PAYHOSSINGLEVY>');
                END LOOP;
   END IF;

IF p_employee_type = 'Intern'
    THEN 
         FOR record_Intern IN cur_Intern(TO_CHAR(l_as_of_date, 'MON-RRRR'))
            LOOP
            out( '<G_PAYHOSSINGLEVY>');	  
            out( '<NATIONAL_IDENTIFIER>' || record_Intern.NATIONAL_IDENTIFIER || '</NATIONAL_IDENTIFIER>');
            out( '<FULL_NAME>' ||           record_Intern.FULL_NAME || '</FULL_NAME>');
            out( '<OFFICE_NUMBER>' ||       record_Intern.OFFICE_NUMBER || '</OFFICE_NUMBER>');
            out( '<CA_GROSS_EARNINGS>' || record_Intern.CA_GROSS_EARNINGS || '</CA_GROSS_EARNINGS>');
            out( '<BASIC_SALARY>' ||        record_Intern.BASIC_SALARY || '</BASIC_SALARY>');
            out( '<CA_HOUS_EMPLOYEE>' ||    record_Intern.CA_HOUS_EMPLOYEE || '</CA_HOUS_EMPLOYEE>');
            out( '<CA_HOUS_EMPLOYER>' ||    record_Intern.CA_HOUS_EMPLOYER || '</CA_HOUS_EMPLOYER>');
            out( '<CA_HOUS_TOTAL>' ||       record_Intern.CA_HOUS_TOTAL || '</CA_HOUS_TOTAL>');
            out( '</G_PAYHOSSINGLEVY>');
                END LOOP;
   END IF;



            out( '</LIST_PAYHOSSINGLEVY>');

           out( '</PAYHOSSINGLEVY>');



    EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line (fnd_file.log, 'Main Error in XXCA_AP_GL_AGING_RPT_PKG.ap_gl_aging_main procedure. Error Message: '||SQLERRM);  
    END PAY_MAIN;




END XXCA_PAY_HOUSING_LEVY_RPT_PKG;
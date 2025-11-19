create or replace PACKAGE   XXCA_REITTANCE_NOTIF_PKG  AS
   
    PROCEDURE XXCA_REITTANCE_NOTIF_TEMP (
        errbuf                      OUT VARCHAR2,
        retcode                     OUT NUMBER,
        p_request_id                 number
);
FUNCTION xxca_pay_file_event (
    p_subscription_guid IN RAW,
    p_event             IN OUT NOCOPY wf_event_t
) RETURN VARCHAR2 ;


    PROCEDURE xxca_reittance_staff_notif (
        errbuf                      OUT VARCHAR2,
        retcode                     OUT NUMBER,
        p_request_id                 number
);

end;






create or replace PACKAGE BODY xxca_reittance_notif_pkg AS

    PROCEDURE xxca_reittance_notif_temp (
        errbuf       OUT VARCHAR2,
        retcode      OUT NUMBER,
        p_request_id NUMBER
    ) IS

        l_bank_sig_group1 VARCHAR2(4000);
        l_bank_sig_group3 VARCHAR2(4000);
        l_bank_sig_group2 VARCHAR2(4000);
        l_amount          NUMBER;
        l_sent_mail_grp   VARCHAR2(4000);
        l_inv_date        DATE;
        l_inv_amount      NUMBER;
        l_inv_num         VARCHAR2(2000);
        g_request_id     NUMBER  := apps.fnd_global.conc_request_id;
        l_request_id  number;
        CURSOR c1 IS
        SELECT DISTINCT
            a.payment_service_request_id,
            a.call_app_pay_service_req_code,
            a.payment_service_request_status,
            sum(b.payment_amount) payment_amount,
            b.payment_date,
            b.payment_process_request_name,
            c.status_code program_status,
            c.argument_text,
            c.program     program_name,
            c.request_id
        FROM
            iby_pay_service_requests a,
            iby_payments_all         b,
            fnd_conc_req_summary_v   c
        WHERE
                a.payment_service_request_id = b.payment_service_request_id
--and b.PAYMENTS_COMPLETE_FLAG not in 'Y'
            AND a.payment_service_request_id = regexp_substr(c.argument_text, '[0-9]+')
            AND c.user_concurrent_program_name IN ( 'CAK KCB Payment Integration File Program', 'CA Bank Payment File Generation Program'
            )
            AND c.request_id = p_request_id
            and c.STATUS_CODE='C'
        GROUP BY 
                a.payment_service_request_id,
            a.call_app_pay_service_req_code,
            a.payment_service_request_status,
            b.payment_date,
            b.payment_process_request_name,
            c.status_code,
            c.argument_text,
            c.program,
            c.request_id
        ORDER BY
            c.request_id DESC;


            cursor get_invoice(p_payment_service_request_id in number) is

                SELECT
                    aia.invoice_num,
                    aia.invoice_amount,
                    aia.invoice_date,
                    aia.description,
                    aca.CHECK_NUMBER,
                    aps.vendor_name Trading_partner

                FROM
                    ap_invoices_all         aia,
                    ap_invoice_payments_all aipa,
                    ap_checks_all           aca,
                    iby_payments_all iby,
                     ap_suppliers aps 
                WHERE
                        aia.invoice_id = aipa.invoice_id
                    AND aipa.check_id = aca.check_id
                    AND aca.payment_id = iby.payment_id
                    and aia.vendor_id=aps.vendor_id
                    and iby.payment_service_request_id=p_payment_service_request_id
                ORDER BY
                    aia.invoice_id DESC;







    BEGIN


      BEGIN
                SELECT
                    LISTAGG(meaning, ',') WITHIN GROUP(
                    ORDER BY
                        meaning
                    )
                INTO l_bank_sig_group1
                FROM
                    fnd_common_lookups
                WHERE
                        lookup_type = 'XXCA_EMAIL_NOTIF_BANK_APPR_G1'
                    AND enabled_flag = 'Y'
                    AND sysdate BETWEEN nvl(start_date_active, sysdate) AND nvl(end_date_active, sysdate);

            EXCEPTION
                WHEN OTHERS THEN
                    l_bank_sig_group1 := NULL;
            END;

            BEGIN
                SELECT
                    LISTAGG(meaning, ',') WITHIN GROUP(
                    ORDER BY
                        meaning
                    )
                INTO l_bank_sig_group2
                FROM
                    fnd_common_lookups
                WHERE
                        lookup_type = 'XXCA_EMAIL_NOTIF_BANK_APPR_G2'
                    AND enabled_flag = 'Y'
                    AND sysdate BETWEEN nvl(start_date_active, sysdate) AND nvl(end_date_active, sysdate);

            EXCEPTION
                WHEN OTHERS THEN
                    l_bank_sig_group2 := NULL;
            END;

            BEGIN
                SELECT
                    LISTAGG(meaning, ',') WITHIN GROUP(
                    ORDER BY
                        meaning
                    )
                INTO l_bank_sig_group3
                FROM
                    fnd_common_lookups
                WHERE
                        lookup_type = 'XXCA_EMAIL_NOTIF_BANK_APPR_G3'
                    AND enabled_flag = 'Y'
                    AND sysdate BETWEEN nvl(start_date_active, sysdate) AND nvl(end_date_active, sysdate);

            EXCEPTION
                WHEN OTHERS THEN
                    l_bank_sig_group3 := NULL;
            END;

            BEGIN


                SELECT
                    SUM(b.payment_amount)
                INTO l_amount

                     FROM
            iby_pay_service_requests a,
            iby_payments_all         b,
            fnd_conc_req_summary_v   c
        WHERE
                a.payment_service_request_id = b.payment_service_request_id
--and b.PAYMENTS_COMPLETE_FLAG not in 'Y'
            AND a.payment_service_request_id = regexp_substr(c.argument_text, '[0-9]+')
            AND c.user_concurrent_program_name IN ( 'CAK KCB Payment Integration File Program', 'CA Bank Payment File Generation Program'
            )
            AND c.request_id = p_request_id
            and c.STATUS_CODE='C'
        ;

            EXCEPTION
                WHEN OTHERS THEN
                    l_amount := 0;
            END;


 IF l_amount <= 5000000 THEN
                l_sent_mail_grp := l_bank_sig_group1;
--                l_sent_mail_grp := 'CHEPKWONY@CA.GO.KE';
            ELSIF
                l_amount > 5000000
                AND l_amount <= 20000000
            THEN
                l_sent_mail_grp := l_bank_sig_group2;
--                 l_sent_mail_grp := 'abongo@ca.go.ke';
            ELSIF l_amount > 20000001 THEN
                l_sent_mail_grp := l_bank_sig_group3;
            END IF;


        fnd_file.put_line(fnd_file.output, '<XXCA_REMITTANCE_TEMPLATE>');
        fnd_file.put_line(fnd_file.output, '<p_request_id>'
                                           || p_request_id
                                           || '</p_request_id>');

        FOR i IN c1 LOOP



/*
           */









            fnd_file.put_line(fnd_file.output, '<G_REM_TEMP>');
            fnd_file.put_line(fnd_file.output, '<L_SENT_MAIL_GRP>'
                                               || l_sent_mail_grp
                                               || '</L_SENT_MAIL_GRP>');


            fnd_file.put_line(fnd_file.output, '<l_amount>'
                                               || l_amount
                                               || '</l_amount>');



            fnd_file.put_line(fnd_file.output, '<call_app_pay_service_req_code>'
                                               || i.call_app_pay_service_req_code
                                               || '</call_app_pay_service_req_code>');

            fnd_file.put_line(fnd_file.output, '<payment_service_request_status>'
                                               || i.payment_service_request_status
                                               || '</payment_service_request_status>');

            fnd_file.put_line(fnd_file.output, '<payment_amount>'
                                               || i.payment_amount
                                               || '</payment_amount>');

            fnd_file.put_line(fnd_file.output, '<payment_date>'
                                               || i.payment_date
                                               || '</payment_date>');


for j in get_invoice(i.payment_service_request_id)
loop

            fnd_file.put_line(fnd_file.output, '<G_REM_INV>');
            fnd_file.put_line(fnd_file.output, '<l_inv_date>'
                                               || j.invoice_date
                                               || '</l_inv_date>');
            fnd_file.put_line(fnd_file.output, '<l_inv_num>'
                                               || j.invoice_num
                                               || '</l_inv_num>');
            fnd_file.put_line(fnd_file.output, '<l_Inv_amount>'
                                               || j.invoice_amount
                                               || '</l_Inv_amount>');
             fnd_file.put_line(fnd_file.output, '<description>'
                                               || j.description
                                               || '</description>');   

                                               fnd_file.put_line(fnd_file.output, '<CHECK_NUMBER>'
                                               || j.CHECK_NUMBER
                                               || '</CHECK_NUMBER>');   

                                               fnd_file.put_line(fnd_file.output, '<Trading_partner>'
                                               || j.Trading_partner
                                               || '</Trading_partner>');   
            fnd_file.put_line(fnd_file.output, '</G_REM_INV>');

            end loop;
            fnd_file.put_line(fnd_file.output, '</G_REM_TEMP>');
        END LOOP;

        fnd_file.put_line(fnd_file.output, '</XXCA_REMITTANCE_TEMPLATE>');

        l_request_id :=
 fnd_request.submit_request(application => 'XDO',
                                           program     => 'XDOBURSTREP',
                                           description =>  'Payment File Remittance Bursting',
                                           start_time  =>  NULL,
                                           sub_request =>  FALSE,
                                           argument1   => NULL,
                                           argument2   =>  g_request_id,
                                           argument3   =>  'Y'
                                           );
    END xxca_reittance_notif_temp;

    FUNCTION xxca_pay_file_event (
    p_subscription_guid IN RAW,
    p_event             IN OUT NOCOPY wf_event_t
) RETURN VARCHAR2 IS

    l_request_id     NUMBER;
    l_program_id     NUMBER;
    l_status_code    VARCHAR2(10);
    l_argument_blob  VARCHAR2(4000);
    l_payroll_name   VARCHAR2(100);
    l_end_date_str   VARCHAR2(100);
    l_end_date       DATE;
    l_payroll_id     NUMBER;
    l_time_period_id NUMBER;
    l_ca_request_id  NUMBER;
    l_err_msg        VARCHAR2(4000);
    L_PHASE_CODE      VARCHAR2(240);

   --
    l_parameter_list wf_parameter_list_t := wf_parameter_list_t();
    l_event_key      VARCHAR2(240);
    l_event_name     VARCHAR2(240);
    l_parameter_t    wf_parameter_t := wf_parameter_t(NULL, NULL);
    l_parameter_name l_parameter_t.name%TYPE;
    l_param_value    l_parameter_t.value%TYPE;
    i                PLS_INTEGER;
    l_error          VARCHAR2(4000);
    l_user_id        fnd_user.user_id%TYPE;-- := fnd_global.user_id;
    l_resp_id        fnd_responsibility.responsibility_id%TYPE;-- := fnd_global.resp_id;
    l_resp_appl_id   fnd_responsibility.application_id%TYPE;--:= fnd_global.resp_appl_id;	
BEGIN
   -- Extract metadata from event parameters
   l_event_name     := p_event.geteventname ();
		l_event_key      := p_event.geteventkey ();
		l_parameter_list := p_event.getparameterlist ();
   l_request_id  := p_event.getvalueforparameter('REQUEST_ID');
   l_program_id  := p_event.getvalueforparameter('CONCURRENT_PROGRAM_ID');
   l_status_code := p_event.getvalueforparameter('STATUS');
   --
   l_user_id  			:= p_event.GetValueForParameter('USER_ID');
		l_resp_id			:= p_event.GetValueForParameter('RESP_ID');
		l_resp_appl_id		:= p_event.GetValueForParameter('RESP_APPL_ID');


   -- Only trigger for matching program and successful completion
   begin

   insert into XXCA.TEST_LOG(REQUEST_ID,CLAIM_TYPE,PROCESS_STATUS,PROCESS_MESSAGE) 
           values(l_request_id,l_program_id,l_status_code,'insert-1');

           COMMIT;
   end;

   IF l_program_id in (56420,106427) --AND l_status_code = 'NORMAL' 
   THEN
   /* BEGIN
        SELECT
            phase_code,
            status_code
        INTO
            l_phase_code,
            l_status_code
        FROM
            fnd_concurrent_requests
        WHERE
            request_id = l_request_id;

			exception 
			when others THEN
			l_phase_code := 'C';
                        l_status_code := 'C';
			end;
*/
       -- IF l_status_code = 'C' THEN



             mo_global.init('SQLAP');
        fnd_global.apps_initialize(user_id => l_user_id, resp_id => l_resp_id,
        resp_appl_id => l_resp_appl_id);
       mo_global.set_policy_context('S', 101);



            l_ca_request_id := fnd_request.submit_request(application => 'XXCA', program => 'XXCA_REITTANCE_NOTIF_TEMP', argument1 => l_request_id
            );

            l_ca_request_id := fnd_request.submit_request(application => 'XXCA', program => 'XXCA_REMIT_FILE_STAFF_EXE', argument1 => l_request_id
            );

            COMMIT;

              begin

   insert into XXCA.TEST_LOG(REQUEST_ID,CLAIM_TYPE,PROCESS_STATUS,PROCESS_MESSAGE) 
           values(l_ca_request_id,l_program_id,l_status_code,'insert-2');

           COMMIT;
   end;

            IF l_ca_request_id = 0 THEN
                wf_core.context(pkg_name => 'xxca_reittance_notif_pkg', proc_name => 'XXCA_PAY_FILE_EVENT', arg1 => p_event.geteventname
                (), arg2 => p_subscription_guid);

                wf_event.seterrorinfo(p_event => p_event, p_type => 'ERROR');
                l_argument_blob := sqlerrm;
            ELSE
             LOOP
                BEGIN
                    SELECT
                        phase_code,
                        status_code
                    INTO
                        l_phase_code,
                        l_status_code
                    FROM
                        fnd_concurrent_requests
                    WHERE
                        request_id = l_ca_request_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_error := substr('Inside l_phase_code Exception: ' || sqlerrm, 1, 4000);
                        l_phase_code := 'C';
                        l_status_code := 'C';


                               begin

   insert into XXCA.TEST_LOG(REQUEST_ID,CLAIM_TYPE,PROCESS_STATUS,PROCESS_MESSAGE) 
           values(l_ca_request_id,l_program_id,l_status_code,l_error);

           COMMIT;
   end;
                END;

                EXIT WHEN
                    l_phase_code = 'C'
                    AND l_status_code = 'C';
            END LOOP;

                RETURN 'SUCCESS';
                COMMIT;
           -- END IF;

        END IF;
      RETURN 'SKIPPED';
    END if;



EXCEPTION
   WHEN OTHERS THEN
      l_err_msg := SQLERRM;



      RETURN 'ERROR';
END xxca_pay_file_event;

 PROCEDURE xxca_reittance_staff_notif (
        errbuf       OUT VARCHAR2,
        retcode      OUT NUMBER,
        p_request_id NUMBER
    ) IS

        l_bank_sig_group1 VARCHAR2(4000);
        l_bank_sig_group3 VARCHAR2(4000);
        l_bank_sig_group2 VARCHAR2(4000);
        l_amount          NUMBER;
        l_sent_mail_grp   VARCHAR2(4000);
        l_inv_date        DATE;
        l_inv_amount      NUMBER;
        l_inv_num         VARCHAR2(2000);
        g_request_id     NUMBER  := apps.fnd_global.conc_request_id;
        l_request_id  number;
        CURSOR c1 IS
        SELECT DISTINCT
            a.payment_service_request_id,
            a.call_app_pay_service_req_code,
            a.payment_service_request_status,
            sum(b.payment_amount) payment_amount,
            b.payment_date,
            b.payment_process_request_name,
            c.status_code program_status,
            c.argument_text,
            c.program     program_name,
            c.request_id
        FROM
            iby_pay_service_requests a,
            iby_payments_all         b,
            fnd_conc_req_summary_v   c
        WHERE
                a.payment_service_request_id = b.payment_service_request_id
--and b.PAYMENTS_COMPLETE_FLAG not in 'Y'
            AND a.payment_service_request_id = regexp_substr(c.argument_text, '[0-9]+')
            AND c.user_concurrent_program_name IN ( 'CAK KCB Payment Integration File Program', 'CA Bank Payment File Generation Program'
            )
            AND c.request_id = p_request_id
            and c.STATUS_CODE='C'
        GROUP BY 
                a.payment_service_request_id,
            a.call_app_pay_service_req_code,
            a.payment_service_request_status,
            b.payment_date,
            b.payment_process_request_name,
            c.status_code,
            c.argument_text,
            c.program,
            c.request_id
        ORDER BY
            c.request_id DESC;


            cursor get_invoice(p_payment_service_request_id in number) is

         SELECT   
                    sum(aia.invoice_amount) invoice_amount,

                    iby.PAYEE_NAME,
                 papf.EMAIL_ADDRESS
         /*   (SELECT LISTAGG(email, ',') WITHIN GROUP (ORDER BY email) AS combined_emails
FROM (
  SELECT 'Abhishek.Gajjada@adktechnologies.com' AS email FROM dual
  UNION ALL
  SELECT 'CHEPKWONY@CA.GO.KE' FROM dual
  UNION ALL
  SELECT 'sosmus.gachuhi@adktechnologies.com' FROM dual
) EMAIL_ADDRESS )EMAIL_ADDRESS */



                FROM
                    ap_invoices_all         aia,
                    ap_invoice_payments_all aipa,
                    ap_checks_all           aca,
                    iby_payments_all iby ,
                    ap_suppliers aps,
                    per_all_people_f papf,
                    per_person_types a 
--                    fnd_user b
                WHERE
                        aia.invoice_id = aipa.invoice_id
                    AND aipa.check_id = aca.check_id
                    AND aca.payment_id = iby.payment_id
                    and iby.PAYEE_SUPPLIER_ID=aps.vendor_id
                    and aps.EMPLOYEE_ID=papf.person_id
                    and papf.person_type_id=a.PERSON_TYPE_ID
                  --  and aps.EMPLOYEE_ID=b.employee_id
                    and sysdate between papf.effective_start_date and effective_end_date
                    and iby.payment_service_request_id=p_payment_service_request_id
                    group by iby.PAYEE_NAME,  papf.EMAIL_ADDRESS

                    ;







    BEGIN






        fnd_file.put_line(fnd_file.output, '<XXCA_REMIT_STAFF_TEMPLATE>');
        fnd_file.put_line(fnd_file.output, '<p_request_id>'
                                           || p_request_id
                                           || '</p_request_id>');

        FOR i IN c1 LOOP







            fnd_file.put_line(fnd_file.output, '<G_REM_STAFF_TEMP>');




            fnd_file.put_line(fnd_file.output, '<call_app_pay_service_req_code>'
                                               || i.call_app_pay_service_req_code
                                               || '</call_app_pay_service_req_code>');

            fnd_file.put_line(fnd_file.output, '<payment_service_request_status>'
                                               || i.payment_service_request_status
                                               || '</payment_service_request_status>');

            fnd_file.put_line(fnd_file.output, '<payment_amount>'
                                               || i.payment_amount
                                               || '</payment_amount>');

            fnd_file.put_line(fnd_file.output, '<payment_date>'
                                               || i.payment_date
                                               || '</payment_date>');


for j in get_invoice(i.payment_service_request_id)
loop




            fnd_file.put_line(fnd_file.output, '<G_staff_INV>');

             fnd_file.put_line(fnd_file.output, '<L_SENT_MAIL_STAFF>'
                                               || j.EMAIL_ADDRESS
                                               || '</L_SENT_MAIL_STAFF>');



            fnd_file.put_line(fnd_file.output, '<l_Inv_amount>'
                                               || j.invoice_amount
                                               || '</l_Inv_amount>');
             fnd_file.put_line(fnd_file.output, '<PAYEE_NAME>'
                                               || j.PAYEE_NAME
                                               || '</PAYEE_NAME>');                                   
            fnd_file.put_line(fnd_file.output, '</G_staff_INV>');

            end loop;
            fnd_file.put_line(fnd_file.output, '</G_REM_STAFF_TEMP>');
        END LOOP;

        fnd_file.put_line(fnd_file.output, '</XXCA_REMIT_STAFF_TEMPLATE>');

        l_request_id :=
 fnd_request.submit_request(application => 'XDO',
                                           program     => 'XDOBURSTREP',
                                           description =>  'Payment File Remittance Bursting',
                                           start_time  =>  NULL,
                                           sub_request =>  FALSE,
                                           argument1   => NULL,
                                           argument2   =>  g_request_id,
                                           argument3   =>  'Y'
                                           );
    END xxca_reittance_staff_notif;





END xxca_reittance_notif_pkg;
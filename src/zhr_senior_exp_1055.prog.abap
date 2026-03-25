REPORT zhr_senior_exp_1055.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         numemp TYPE n LENGTH 4,
         tipcol TYPE numc1,
         numcad TYPE n LENGTH 9,
         datref TYPE c LENGTH 10,
         natetg TYPE c,
         nivetg TYPE numc1,
         areatu TYPE c LENGTH 50,
         aposeg TYPE c LENGTH 30,
         valbol TYPE p LENGTH 9 DECIMALS 2,
         preter TYPE c LENGTH 10,
         insens TYPE n LENGTH 8,
         ageint TYPE n LENGTH 8,
         empcoo TYPE n LENGTH 4,
         tipcoo TYPE numc1,
         numcoo TYPE n LENGTH 9,
         nomcoo TYPE c LENGTH 70,
         cpfcoo TYPE c LENGTH 14,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

*-Tela de Seleção -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_serv TYPE sapb-sappfad DEFAULT '/usr/sap/tmp/'.
SELECTION-SCREEN END OF BLOCK blc1.

*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*&---------------------------------------------------------------------*
*&      Form  ZF_SEARCH_HELP_DIRECTORY
*&---------------------------------------------------------------------*
FORM zf_search_help_directory.

  DATA lv_serverfile TYPE string.
  CALL FUNCTION '/SAPDMC/LSM_F4_SERVER_FILE'
    IMPORTING
      serverfile       = lv_serverfile
    EXCEPTIONS
      canceled_by_user = 1
      OTHERS           = 2.

  IF NOT lv_serverfile IS INITIAL.
    p_serv = |{ lv_serverfile }/|.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_NORMALIZAR_CAMINHOS
*&---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_EXPORTAR_DADOS
*&---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA: lt_conv TYPE truxs_t_text_data.

  DATA: ls_data TYPE gy_file.

  DATA: lv_filename TYPE string,
        lv_header   TYPE string,
        lv_line     TYPE string.

  DATA: lv_erro TYPE flag.

  lv_filename = p_serv && sy-datum && '_SENIOR_1055.csv'.
  OPEN DATASET lv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT."FOR OUTPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
  IF sy-subrc <> 0.
    MESSAGE |Erro abrindo arquivo { lv_filename }| TYPE 'E'.
  ENDIF.

  SELECT pa0001~pernr,pa0001~bukrs,pa0001~persg,pa0001~persk,pa0001~plans,
         pa0008~lga01,pa0008~bet01,
         pa0016~ctedt,
         pa0168~bplan,
         pa0398~begda,pa0398~internshp_type,pa0398~educ_level,pa0398~educ_inst_cod,pa0398~int_agent_cod INTO TABLE @DATA(lt_dados)
   FROM pa0001
   INNER JOIN pa0008 ON pa0008~pernr EQ pa0001~pernr
   INNER JOIN pa0016 ON pa0016~pernr EQ pa0001~pernr
   INNER JOIN pa0168 ON pa0168~pernr EQ pa0001~pernr
   INNER JOIN pa0398 ON pa0398~pernr EQ pa0001~pernr
  WHERE pa0001~endda EQ '99991231'
    AND pa0001~persk EQ '50'
    AND pa0008~endda EQ '99991231'
    AND pa0008~lga01 EQ '0020'
    AND pa0016~endda EQ '99991231'
    AND pa0398~endda EQ '99991231'.

  LOOP AT lt_dados ASSIGNING FIELD-SYMBOL(<lf_dados>).
    PERFORM zf_process_registration USING <lf_dados>.
  ENDLOOP.

  CALL FUNCTION 'SAP_CONVERT_TO_CSV_FORMAT'
    EXPORTING
      i_field_seperator    = ';'
    TABLES
      i_tab_sap_data       = gt_file
    CHANGING
      i_tab_converted_data = lt_conv
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  " Header
  DATA(lo_typedescr) = cl_abap_typedescr=>describe_by_data( ls_data ).
  IF lo_typedescr->kind = cl_abap_typedescr=>kind_struct.
    DATA(lo_structdescr) = CAST cl_abap_structdescr( lo_typedescr ).
    DATA(lt_components) = lo_structdescr->components.
    LOOP AT lt_components ASSIGNING FIELD-SYMBOL(<lf_component>).
      lv_header = |{ lv_header }| & |;|  & |{ <lf_component>-name }|.
    ENDLOOP.
    lv_header = lv_header+1.
  ENDIF.
  INSERT lv_header INTO lt_conv INDEX 1.

  LOOP AT lt_conv INTO DATA(ls_conv).
    TRANSFER ls_conv TO lv_filename.
    IF sy-subrc NE 0.
      lv_erro = abap_true. EXIT.
    ENDIF.
  ENDLOOP.
  CLOSE DATASET lv_filename.

  IF lv_erro IS NOT INITIAL.
    MESSAGE 'Erro ao gerar arquivo' TYPE 'E'.
  ELSE.
    WRITE: / 'Arquivo gerado com sucesso:', lv_filename.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESS_REGISTRATION
*&---------------------------------------------------------------------*
FORM zf_process_registration USING us_dados TYPE any.

  DATA: lv_persg  TYPE persg,
        lv_tipcol TYPE c LENGTH 1,
        lv_dats   TYPE d,
        lv_datopc TYPE char10.

  APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

  " Código da Empresa
  ASSIGN COMPONENT 'BUKRS' OF STRUCTURE us_dados TO FIELD-SYMBOL(<lf_value>).
  <lf_file>-numemp = <lf_value>.

  " Tipo Colaborador
  ASSIGN COMPONENT 'PERSG' OF STRUCTURE us_dados TO <lf_value>.
  lv_persg = <lf_value>.
  PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior USING lv_persg CHANGING lv_tipcol.
  <lf_file>-tipcol = lv_tipcol.

  " Cadastro do Colaborador
  ASSIGN COMPONENT 'PERNR' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-numcad = <lf_value>.

  " Data de Referência
  ASSIGN COMPONENT 'BEGDA' OF STRUCTURE us_dados TO <lf_value>.
  lv_dats = <lf_value>.
  PERFORM f_conv_date   IN PROGRAM zhr_export_senior USING lv_dats CHANGING lv_datopc.
  <lf_file>-datref = lv_datopc.

  " Natureza do Estágio
  ASSIGN COMPONENT 'INTERNSHP_TYPE' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-natetg = <lf_value>.

  " Nível do Estágio
  ASSIGN COMPONENT 'EDUC_LEVEL' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-nivetg = <lf_value>.

  " Área de atuação do estagiário
*  <lf_file>-areatu

  " Apólice de Seguro
  ASSIGN COMPONENT 'BPLAN' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-aposeg = <lf_value>.

  " Valor da Bolsa
  ASSIGN COMPONENT 'BET01' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-valbol = <lf_value>.

  " Data prevista para o término do estágio
  ASSIGN COMPONENT 'CTEDT' OF STRUCTURE us_dados TO <lf_value>.
  lv_dats = <lf_value>.
  PERFORM f_conv_date IN PROGRAM zhr_export_senior USING lv_dats CHANGING lv_datopc.
  <lf_file>-preter = lv_datopc.

  " Instituição de Ensino
  ASSIGN COMPONENT 'EDUC_INST_COD' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-insens = <lf_value>.

  " Agente de Integração
  ASSIGN COMPONENT 'INT_AGENT_COD' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-ageint = <lf_value>.

  " Empresa do Supervisor
*  <lf_file>-empcoo

  " Tipo Supervisor
*  <lf_file>-tipcoo

  " Cadastro do Supervisor
*  <lf_file>-numcoo

  " Nome do Supervisor
*  <lf_file>-nomcoo

  " Número do CPF do Supervisor
*  <lf_file>-cpfcoo

ENDFORM.
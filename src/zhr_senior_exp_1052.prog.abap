REPORT zhr_senior_exp_1052.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         codesc TYPE c LENGTH 8,
         nomesc TYPE c LENGTH 30,
         tipesc TYPE c LENGTH 1,
         turesc TYPE n LENGTH 1,
         hordsr TYPE p DECIMALS 2,
         horsem TYPE p DECIMALS 2,
         pagepf TYPE c LENGTH 1,
         tipfer TYPE c LENGTH 1,
         tipjor TYPE n LENGTH 1,
         desjor TYPE c LENGTH 100,
         tipjos TYPE n LENGTH 2,
         dessim TYPE c LENGTH 999,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

*-Tela de Sele??o -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_locl  TYPE string LOWER CASE,
            p_serv TYPE sapb-sappfad DEFAULT '/usr/sap/tmp/'.
SELECTION-SCREEN END OF BLOCK blc1.
*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  IF p_locl IS INITIAL AND p_serv IS INITIAL.
    MESSAGE 'Informe o destino local ou no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_exportar_dados.
*&---------------------------------------------------------------------*
*&      Form  F_EXPORTAR_DADOS
*&---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA: lt_conv TYPE truxs_t_text_data.

  DATA: ls_data TYPE gy_file.

  DATA: lv_filename TYPE string,
        lv_header   TYPE string.

  lv_filename = sy-datum && '_SENIOR_1052.csv'.
  
  SELECT t508a~schkz,t508a~zmodn,t508a~wostd,
         t508s~rtext
    INTO TABLE @DATA(lt_dados)
    FROM t508a
    INNER JOIN t508s ON t508s~zeity EQ t508a~zeity
                    AND t508s~mofid EQ t508a~mofid
                    AND t508s~mosid EQ t508a~mosid
                    AND t508s~schkz EQ t508a~schkz
   WHERE t508a~mofid EQ 'BR'
     AND t508a~mosid EQ '37'
     AND t508s~sprsl EQ @sy-langu.

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

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior
    USING lv_filename
    CHANGING lt_conv p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', lv_filename.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESS_REGISTRATION
*&---------------------------------------------------------------------*
FORM zf_process_registration USING us_dados TYPE any.

  APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

  " C?digo da Escala
  ASSIGN COMPONENT 'SCHKZ' OF STRUCTURE us_dados
    TO FIELD-SYMBOL(<lf_value>).
  <lf_file>-codesc = <lf_value>.

  " Nome da Escala
  ASSIGN COMPONENT 'RTEXT' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-nomesc = <lf_value>.

  " Tipo da Escala
*<lf_file>-TIPESC

  " Turno da Escala
*  <lf_file>-turesc = .

  " Horas de DSR
*<lf_file>-HORDSR

  " Horas na Semana
  ASSIGN COMPONENT 'WOSTD' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-horsem = <lf_value>.

  " Pagar extras proporcionais no feriado
*<lf_file>-PAGEPF

  " Tipo de Feriado da Escala
*<lf_file>-TIPFER

  " Tipo de jornada para o eSocial
*<lf_file>-TIPJOR

  " Descri??o da Jornada eSocial
*<lf_file>-DESJOR

  " Tipo de jornada para o eSocial Simplificado
*<lf_file>-TIPJOS

  " Descri??o da Jornada eSocial Simplificado
*<lf_file>-DESSIM

ENDFORM.

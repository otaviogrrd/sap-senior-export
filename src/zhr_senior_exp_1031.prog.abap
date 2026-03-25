REPORT zhr_export_senior_1031.

PARAMETERS: p_file TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1031.csv'.

  gv_header =
  'NUMEMP;TIPCOL;NUMCAD;CODDEP;NOMDEP;NOMMAE;GRAPAR;TIPSEX;LIMIRF;DATNAS;DATINV;'
  && 'NOMCAR;NUMLIV;NUMREG;NUMFOL;NUMCPF;PENJUD;DATOBI;NUMCER;NOMCOM;MATNAS;MATOBI;'
  && 'NASVIV;CARSUS;ESTCIV;GRAINS;TIPDEP;LIMSAF;DEXCID;ESTCID;EMICID;NUMCID;NUMRIC;'
  && 'NUMELE;NUMPIS;ESTCTP;NUMCTP;SERCTP;DIGCAR'.

*---------------------------------------------------------------------*
* SELECT
*---------------------------------------------------------------------*
  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,

    p21~subty,
    p21~famsa,
    p21~fcnam,
    p21~fasex,
    p21~fgbdt,

    p397~icnum,
    p397~escol,
    p397~noreu,
    p397~nhcnr,
    p397~carto,
    p397~noliv,
    p397~noreg,
    p397~nofol,
    p397~mothe

  INTO TABLE @DATA(gt_dep)

  FROM pa0001 AS p1

  INNER JOIN pa0021 AS p21
    ON p21~pernr = p1~pernr
   AND p21~begda <= @sy-datum
   AND p21~endda >= @sy-datum

  LEFT JOIN pa0397 AS p397
    ON p397~pernr = p21~pernr
   AND p397~subty = p21~subty
   AND p397~begda <= @sy-datum
   AND p397~endda >= @sy-datum

  WHERE p1~begda <= @sy-datum
    AND p1~endda >= @sy-datum.

*---------------------------------------------------------------------*
* SORT + REMOVE DUPLICATES
*---------------------------------------------------------------------*

  SORT gt_dep BY pernr subty.

  DELETE ADJACENT DUPLICATES FROM gt_dep COMPARING
    pernr subty.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* LOOP
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datnas TYPE char10,
    lv_tipsex TYPE c LENGTH 1,
    lv_coddep TYPE n LENGTH 2,
    lv_tipdep TYPE n LENGTH 2.

  LOOP AT gt_dep ASSIGNING FIELD-SYMBOL(<fs_dep>).

*---------------------------------------------------------------------*
* REGRA: CODDEP â‰  ZERO
*---------------------------------------------------------------------*

    lv_coddep = <fs_dep>-subty.
    IF lv_coddep = 0.
      CONTINUE.
    ENDIF.

*---------------------------------------------------------------------*
* ConversÃµes
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_dep>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_tipsex IN PROGRAM zhr_export_senior
      USING <fs_dep>-fasex
      CHANGING lv_tipsex.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_dep>-fgbdt
      CHANGING lv_datnas.

*---------------------------------------------------------------------*
* TIPDEP (DE/PARA baseado no GRAPAR)
*---------------------------------------------------------------------*

    CLEAR lv_tipdep.

    CASE <fs_dep>-famsa.

      WHEN '1'. lv_tipdep = '01'. " Filho
      WHEN '2'. lv_tipdep = '02'. " CÃ´njuge
      WHEN '3'. lv_tipdep = '03'. " Pai
      WHEN '4'. lv_tipdep = '04'. " MÃ£e
      WHEN OTHERS.
        lv_tipdep = '99'.

    ENDCASE.

*---------------------------------------------------------------------*
* PensÃ£o Judicial
*---------------------------------------------------------------------*

    DATA(lv_penjud) = 'N'.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_dep>-bukrs      && ';' && " NUMEMP
      lv_tipcol           && ';' && " TIPCOL
      <fs_dep>-pernr      && ';' && " NUMCAD
      lv_coddep           && ';' && " CODDEP
      <fs_dep>-fcnam      && ';' && " NOMDEP
      <fs_dep>-mothe      && ';' && " NOMMAE
      <fs_dep>-famsa      && ';' && " GRAPAR
      lv_tipsex           && ';' && " TIPSEX
      ''                  && ';' && " LIMIRF
      lv_datnas           && ';' && " DATNAS
      ''                  && ';' && " DATINV
      <fs_dep>-carto      && ';' && " NOMCAR
      <fs_dep>-noliv      && ';' && " NUMLIV
      <fs_dep>-noreg      && ';' && " NUMREG
      <fs_dep>-nofol      && ';' && " NUMFOL
      <fs_dep>-icnum      && ';' && " NUMCPF
      lv_penjud           && ';' && " PENJUD
      ''                  && ';' && " DATOBI
      ''                  && ';' && " NUMCER
      <fs_dep>-fcnam      && ';' && " NOMCOM
      <fs_dep>-noreu      && ';' && " MATNAS
      ''                  && ';' && " MATOBI
      ''                  && ';' && " NASVIV
      <fs_dep>-nhcnr      && ';' && " CARSUS
      ''                  && ';' && " ESTCIV
      <fs_dep>-escol      && ';' && " GRAINS
      lv_tipdep           && ';' && " TIPDEP
      ''                  && ';' && " LIMSAF
      ''                  && ';' && " DEXCID
      ''                  && ';' && " ESTCID
      ''                  && ';' && " EMICID
      ''                  && ';' && " NUMCID
      ''                  && ';' && " NUMRIC
      ''                  && ';' && " NUMELE
      ''                  && ';' && " NUMPIS
      ''                  && ';' && " ESTCTP
      ''                  && ';' && " NUMCTP
      ''                  && ';' && " SERCTP
      ''.                             " DIGCAR

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado:', gv_filename.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      default_extension = 'csv'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_fullpath IS NOT INITIAL.
    p_file = lv_fullpath.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  lv_fullpath = p_file.

  IF lv_fullpath IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_save_dialog
      EXPORTING
        default_extension = 'csv'
        default_file_name = pv_filename
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_fullpath IS INITIAL.
      MESSAGE 'Selecao de arquivo cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

  p_file = lv_fullpath.

ENDFORM.

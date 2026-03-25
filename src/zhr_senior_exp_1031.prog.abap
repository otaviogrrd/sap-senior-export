REPORT zhr_senior_exp_1031.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

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
  'NUMEMP;TIPCOL;NUMCAD;CODDEP;NOMDEP;NOMMAE;'
  && 'GRAPAR;TIPSEX;LIMIRF;DATNAS;DATINV;'
  && 'NOMCAR;NUMLIV;NUMREG;NUMFOL;NUMCPF;PENJUD;DATOBI;'
  && 'NUMCER;NOMCOM;MATNAS;MATOBI;'
  && 'NASVIV;CARSUS;ESTCIV;GRAINS;TIPDEP;LIMSAF;DEXCID;'
  && 'ESTCID;EMICID;NUMCID;NUMRIC;'
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
* REGRA: CODDEP ? ZERO
*---------------------------------------------------------------------*

    lv_coddep = <fs_dep>-subty.
    IF lv_coddep = 0.
      CONTINUE.
    ENDIF.

*---------------------------------------------------------------------*
* Convers?es
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
      WHEN '2'. lv_tipdep = '02'. " C?njuge
      WHEN '3'. lv_tipdep = '03'. " Pai
      WHEN '4'. lv_tipdep = '04'. " M?e
      WHEN OTHERS.
        lv_tipdep = '99'.

    ENDCASE.

*---------------------------------------------------------------------*
* Pens?o Judicial
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

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado:', gv_filename.

ENDFORM.

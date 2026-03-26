REPORT zhr_senior_exp_1030.

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

  gv_filename = sy-datum && '_SENIOR_1030.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;SEQALT;CODMOT;VALSAL;'
  && 'TIPSAL;PERREA'.

*---------------------------------------------------------------------*
* SELECT
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p8~begda,
    p8~lga01,
    p8~bet01,
    p8~preas
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  INNER JOIN pa0008 AS p8
    ON p8~pernr = p1~pernr.

*---------------------------------------------------------------------*
* SORT
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda.

*---------------------------------------------------------------------*
* REMOVE DUPLICATES
*---------------------------------------------------------------------*

  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING
    pernr begda bet01.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* LOOP
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datalt TYPE char10,
    lv_seqalt TYPE n LENGTH 2 VALUE '00',
    lv_lastsal TYPE pa0008-bet01,
    lv_tipsal  TYPE string.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

*---------------------------------------------------------------------*
* MUDAN?A REAL (SAL?RIO)
*---------------------------------------------------------------------*

    AT NEW pernr.
      CLEAR: lv_lastsal, lv_seqalt.
    ENDAT.

    IF <fs_hist>-bet01 = lv_lastsal.
      CONTINUE.
    ENDIF.

    lv_lastsal = <fs_hist>-bet01.

*---------------------------------------------------------------------*
* Sequ?ncia
*---------------------------------------------------------------------*

    ADD 1 TO lv_seqalt.

*---------------------------------------------------------------------*
* Convers?es
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-begda
      CHANGING lv_datalt.

    CLEAR lv_tipsal.

    IF <fs_hist>-lga01 IS NOT INITIAL.
      SELECT SINGLE lgtxt
        INTO lv_tipsal
        FROM t512t
       WHERE sprsl = sy-langu
         AND molga = '37'
         AND lgart = <fs_hist>-lga01.
    ENDIF.

*---------------------------------------------------------------------*
* Percentual de reajuste (opcional)
*---------------------------------------------------------------------*

    DATA(lv_perrea) = ''.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    DATA(lv_numemp) = ||.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_hist>-bukrs
      CHANGING lv_numemp.

    gv_line =
      lv_numemp         && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      lv_seqalt         && ';' && " SEQALT
      <fs_hist>-preas   && ';' && " CODMOT
      <fs_hist>-bet01   && ';' && " VALSAL
      lv_tipsal         && ';' && " TIPSAL
      lv_perrea.                   " PERREA

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado:', gv_filename.

ENDFORM.

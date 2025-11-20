/*
 * Macro Name:    dv_smry
 * Macro Purpose: 方案偏离汇总
 * Author:        wtwang
 * Version Date:  2025-11-20
*/

%macro dv_smry(indata,
               outdata,
               dvseq                = dvseq,
               dvsev                = #null,
               dvsev_by             = %nrstr(&arm),
               dvtyp                = #null,
               dvtyp_by             = %nrstr(&arm),
               usubjid              = usubjid,
               arm                  = #null,
               arm_by               = %nrstr(&arm),
               format_freq          = best12.,
               format_rate          = percentn9.2,
               format_p             = pvalue6.4,
               debug                = false) / parmbuff;
    /*  indata:                 不良事件 ADaM 数据集名称
     *  outdata:                保存汇总结果的数据集名称
     *  aeseq:                  变量-方案偏离序号
     *  usubjid:                变量-受试者唯一编号
     *  arm:                    变量-试验组别，#null 表示单组
     *  arm_by:                 变量-试验组别的排序方式，可能的取值有：数值型变量、输出格式、#null，#null 表示单组
     *  format_freq:            例数和例次的输出格式
     *  format_rate:            率的输出格式
     *  format_p:               p 值的输出格式
     *  debug:                  调试模式
    */

    /*统一参数大小写*/
    %let indata                  = %sysfunc(strip(%superq(indata)));
    %let outdata                 = %sysfunc(strip(%superq(outdata)));
    %let aeseq                   = %upcase(%sysfunc(strip(%bquote(&aeseq))));
    %let usubjid                 = %upcase(%sysfunc(strip(%bquote(&usubjid))));
    %let arm                     = %upcase(%sysfunc(strip(%bquote(&arm))));
    %let arm_by                  = %upcase(%sysfunc(strip(%bquote(&arm_by))));
    %let format_freq             = %upcase(%sysfunc(strip(%bquote(&format_freq))));
    %let format_rate             = %upcase(%sysfunc(strip(%bquote(&format_rate))));
    %let format_p                = %upcase(%sysfunc(strip(%bquote(&format_p))));
    %let debug                   = %upcase(%sysfunc(strip(%bquote(&debug))));

    /*参数预处理*/
    /*arm*/
    %if %superq(arm) = #NULL %then %do;
        %let arm_n = 0;
    %end;

    /*arm_by*/
    %if %superq(arm) ^= #NULL %then %do;
        %if %superq(arm_by) = #NULL %then %do;
            %put ERROR: 参数 ARM 不为 #NULL，必须指定 arm_by！;
            %goto exit;
        %end;
        %else %do;
            %let reg_arm_by_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)|(?:([A-Za-z_]+(?:\d+[A-Za-z_]+)?)\.))(?:\(\s*((?:DESC|ASC)(?:ENDING)?)\s*\))?$/)));
            %if %sysfunc(prxmatch(&reg_arm_by_id, %superq(arm_by))) %then %do;
                %let arm_by_var       = %sysfunc(prxposn(&reg_arm_by_id, 1, %superq(arm_by)));
                %let arm_by_fmt       = %sysfunc(prxposn(&reg_arm_by_id, 2, %superq(arm_by)));
                %let arm_by_direction = %sysfunc(prxposn(&reg_arm_by_id, 3, %superq(arm_by)));

                /*检查排序方向*/
                %if %bquote(&arm_by_direction) = %bquote() %then %do;
                    %put NOTE: 未指定分组的排序方向，默认升序排列！;
                    %let arm_by_direction = ASCENDING;
                %end;
                %else %if %bquote(&arm_by_direction) = ASC %then %do;
                    %let arm_by_direction = ASCENDING;
                %end;
                %else %if %bquote(&arm_by_direction) = DESC %then %do;
                    %let arm_by_direction = DESCENDING;
                %end;

                /*使用格式排序*/
                %if %bquote(&arm_by_fmt) ^= %bquote() %then %do;
                    proc sql noprint;
                        select libname, memname, source into :arm_by_fmt_libname, :arm_by_fmt_memname, :arm_by_fmt_source from dictionary.formats where fmtname = "&arm_by_fmt";
                    quit;

                    proc format library = &arm_by_fmt_libname..&arm_by_fmt_memname cntlout = tmp_arm_by_fmt;
                        select &arm_by_fmt;
                    run;

                    proc sql noprint;
                        create table tmp_arm_sorted as
                            select
                                label,
                                (case when start = "LOW"  then -constant("BIG")
                                      when start = "HIGH" then  constant("BIG")
                                      else input(strip(start), 8.)
                                end)             as arm_by_fmt_start,
                                (case when end = "LOW"  then -constant("BIG")
                                      when end = "HIGH" then  constant("BIG")
                                      else input(strip(end), 8.)
                                end)             as arm_by_fmt_end
                            from tmp_arm_by_fmt
                            order by arm_by_fmt_start &arm_by_direction, arm_by_fmt_end &arm_by_direction;
                        select label into :arm_1- from tmp_arm_sorted;
                        %let arm_n = &sqlobs;
                    quit;
                %end;

                /*使用变量排序*/
                %if %bquote(&arm_by_var) ^= %bquote() %then %do;
                    proc sort data = %superq(indata) out = tmp_arm_sorted(keep = &arm) nodupkey;
                        by %if &arm_by_direction = DESCENDING %then %do; DESCENDING %end; &arm_by_var;
                    run;
                    proc sql noprint;
                        select &arm into :arm_1- from tmp_arm_sorted;
                    quit;
                    %let arm_n = &sqlobs;
                %end;
            %end;
            %else %do;
                %put ERROR: 参数 arm_by = %superq(arm_by) 格式不正确！;
                %goto exit;
            %end;
        %end;
    %end;

    /*sort_by*/
    %let reg_sort_by_unit_id = %sysfunc(prxparse(%bquote(/(?:#(G\d+))?#(FREQ|TIME)(?:\((ASC|DESC)(?:ENDING)?\))?/)));
    %let start = 1;
    %let stop = %length(&sort_by);
    %let position = 0;
    %let length = 0;
    %let sort_by_part_n = 0;
    %syscall prxnext(reg_sort_by_unit_id, start, stop, sort_by, position, length);
    %do %while (&position > 0);
        %let sort_by_part_n = %eval(&sort_by_part_n + 1);
        %let sort_by_part_&sort_by_part_n = %substr(&sort_by, &position, &length);
        %syscall prxnext(reg_sort_by_unit_id, start, stop, sort_by, position, length);
    %end;

    %if &sort_by_part_n = 0 %then %do;
        %put ERROR: 参数 sort_by = %superq(sort_by) 格式不正确！;
        %goto exit;
    %end;
    %else %do;
        %do i = 1 %to &sort_by_part_n;
            %if %sysfunc(prxmatch(&reg_sort_by_unit_id, &&sort_by_part_&i)) %then %do;
                %let sort_by_part_&i._arm       = %sysfunc(prxposn(&reg_sort_by_unit_id, 1, &&sort_by_part_&i)); /*根据哪个组别排序*/
                %let sort_by_part_&i._stat      = %sysfunc(prxposn(&reg_sort_by_unit_id, 2, &&sort_by_part_&i)); /*根据什么统计量排序*/
                %let sort_by_part_&i._direction = %sysfunc(prxposn(&reg_sort_by_unit_id, 3, &&sort_by_part_&i)); /*排序方向*/

                %if &&sort_by_part_&i._arm = %bquote() %then %do;
                    %let sort_by_part_&i._arm = ALL;
                %end;
                %else %do;
                    %if %substr(&&sort_by_part_&i._arm, 2) > &arm_n %then %do;
                        %put ERROR: 排序规则 &&sort_by_part_&i 指定了不存在的组别！;
                        %goto exit;
                    %end;
                %end;

                %if &&sort_by_part_&i._direction = %bquote() %then %do;
                    %let sort_by_part_&i._direction = DESCENDING;
                %end;
                %else %do;
                    %let sort_by_part_&i._direction = &&sort_by_part_&i._direction.ENDING;
                %end;
            %end;
        %end;
    %end;


    /*复制 indata*/
    data tmp_indata;
        set %superq(indata);

        if not missing(&aeseq) and missing(&aesoc)   then &aesoc   = %unquote(%str(%')%superq(unencoded_text)%str(%'));
        if not missing(&aeseq) and missing(&aedecod) then &aedecod = %unquote(%str(%')%superq(unencoded_text)%str(%'));
    run;

    /*创建各组别子集数据集，计算受试者数量*/
    proc sql noprint;
        select count(distinct &usubjid) into :subj_n from tmp_indata;
        %do i = 1 %to &arm_n;
            create table tmp_indata_arm_&i as select * from tmp_indata where &arm = %unquote(%str(%')%superq(arm_&i)%str(%'));
            select count(distinct &usubjid) into :arm_&i._subj_n from tmp_indata_arm_&i;
        %end;
    quit;

    /*创建宏变量，存储 aesoc, aedecod 各水平名称*/
    proc sql noprint;
        create table tmp_indata_subset as
            select * from tmp_indata %if %superq(arm) ^= #NULL %then %do;
                                         where &arm in (%do i = 1 %to &arm_n;
                                                            %unquote(%str(%')%superq(arm_&i)%str(%'))
                                                        %end;)
                                     %end;
                                     ;
        select distinct &aesoc into :&aesoc._1- from tmp_indata_subset where not missing(&aeseq);
        %let &aesoc._n = &sqlobs;
        %do i = 1 %to &&&aesoc._n;
            select distinct &aedecod into :&aesoc._&i._&aedecod._1- from tmp_indata_subset where not missing(&aeseq) and &aesoc = "&&&aesoc._&i";
            %let &aesoc._&i._&aedecod._n = &sqlobs;
        %end;
    quit;

    /*计算 aesoc, aedecod 值的最大长度*/
    %let &aesoc._len_max   = 1;
    %let &aedecod._len_max = 1;
    %do i = 1 %to &&&aesoc._n;
        %let &aesoc._len_max = %sysfunc(max(%length(&&&aesoc._&i), &&&aesoc._len_max));
        %do j = 1 %to &&&aesoc._&i._&aedecod._n;
            %let &aedecod._len_max = %sysfunc(max(%length(&&&aesoc._&i._&aedecod._&j), &&&aedecod._len_max));
        %end;
    %end;

    /*获取 aesoc 和 aedecod 的标签*/
    proc sql noprint;
        select coalescec(label, upcase(name)) into :&aesoc._label   trimmed from dictionary.columns where libname = "WORK" and memname = "TMP_INDATA" and upcase(name) = "&aesoc";
        select coalescec(label, upcase(name)) into :&aedecod._label trimmed from dictionary.columns where libname = "WORK" and memname = "TMP_INDATA" and upcase(name) = "&aedecod";
    quit;

    /*创建基数据集*/
    proc sql noprint;
        create table tmp_base
            (
                AT_LEAST                 char(%length(%superq(at_least_text))) label = %unquote(%str(%')%superq(at_least_text)%str(%')),
                &aesoc                   char(&&&aesoc._len_max)               label = %unquote(%str(%')%superq(&aesoc._label)%str(%')),
                &aesoc._FLAG             num(8)                                label = %unquote(%str(%')%superq(&aesoc._label)（FLAG）%str(%')),
                &aesoc._UNENCODED_FLAG   num(8)                                label = %unquote(%str(%')%superq(&aesoc._label)-未编码（FLAG）%str(%')),
                &aedecod                 char(&&&aedecod._len_max)             label = %unquote(%str(%')%superq(&aedecod._label)%str(%')),
                &aedecod._FLAG           num(8)                                label = %unquote(%str(%')%superq(&aedecod._label)（FLAG）%str(%')),
                &aedecod._UNENCODED_FLAG num(8)                                label = %unquote(%str(%')%superq(&aedecod._label)-未编码（FLAG）%str(%')),
                %do i = 1 %to &arm_n;
                    &aesoc._G&i._FREQ    num(8)                                label = %unquote(%str(%')%superq(&aesoc._label)（%superq(arm_&i)-例数）%str(%')),
                    &aesoc._G&i._TIME    num(8)                                label = %unquote(%str(%')%superq(&aesoc._label)（%superq(arm_&i)-例次）%str(%')),
                    &aedecod._G&i._FREQ  num(8)                                label = %unquote(%str(%')%superq(&aedecod._label)（%superq(arm_&i)-例数）%str(%')),
                    &aedecod._G&i._TIME  num(8)                                label = %unquote(%str(%')%superq(&aedecod._label)（%superq(arm_&i)-例次）%str(%')),
                    G&i._FREQ            num(8)                                label = %unquote(%str(%')%superq(arm_&i)-例数%str(%')),
                    G&i._TIME            num(8)                                label = %unquote(%str(%')%superq(arm_&i)-例次%str(%')),
                    G&i._FREQ_RATE       num(8)                                label = %unquote(%str(%')%superq(arm_&i)-例数率%str(%')),
                    G&i._TIME_RATE       num(8)                                label = %unquote(%str(%')%superq(arm_&i)-例次率%str(%')),
                %end;
                &aesoc._ALL_FREQ         num(8)                                label = %unquote(%str(%')%superq(&aesoc._label)（合计-例数）%str(%')),
                &aesoc._ALL_TIME         num(8)                                label = %unquote(%str(%')%superq(&aesoc._label)（合计-例次）%str(%')),
                &aedecod._ALL_FREQ       num(8)                                label = %unquote(%str(%')%superq(&aedecod._label)（合计-例数）%str(%')),
                &aedecod._ALL_TIME       num(8)                                label = %unquote(%str(%')%superq(&aedecod._label)（合计-例次）%str(%')),
                ALL_FREQ                 num(8)                                label = %unquote(%str(%')合计-例数%str(%')),
                ALL_TIME                 num(8)                                label = %unquote(%str(%')合计-例次%str(%')),
                ALL_FREQ_RATE            num(8)                                label = %unquote(%str(%')合计-例数率%str(%')),
                ALL_TIME_RATE            num(8)                                label = %unquote(%str(%')合计-例次率%str(%'))
            );

        %if &&&aesoc._n > 0 %then %do;
            insert into tmp_base(AT_LEAST, &aesoc, &aesoc._FLAG, &aedecod, &aedecod._FLAG)
                %do i = 1 %to &&&aesoc._n;
                    values ("", "&&&aesoc._&i", 1, "", 0)
                    %do j = 1 %to &&&aesoc._&i._&aedecod._n;
                        values ("", "&&&aesoc._&i", 1, "&&&aesoc._&i._&aedecod._&j", 1)
                    %end;
                %end;
                ;
        %end;

        update tmp_base set &aesoc._UNENCODED_FLAG   = ifn(&aesoc   = %unquote(%str(%')%superq(unencoded_text)%str(%')), 1, 0);
        update tmp_base set &aedecod._UNENCODED_FLAG = ifn(&aedecod = %unquote(%str(%')%superq(unencoded_text)%str(%')), 1, 0);
    quit;

    /*统计至少发生一次不良事件的例数和例次*/
    %if %superq(at_least) = TRUE %then %do;
        proc sql noprint;
            create table tmp_desc_at_least like tmp_base;
            insert into tmp_desc_at_least
                set AT_LEAST       = %unquote(%str(%')%superq(at_least_text)%str(%')),
                    &aesoc._FLAG   = 0,
                    &aedecod._FLAG = 0,
                    %do i = 1 %to &arm_n;
                        &aesoc._G&i._FREQ = (select count(distinct &usubjid) from tmp_indata_arm_&i where not missing(&aeseq)),
                        &aesoc._G&i._TIME = (select count(&usubjid)          from tmp_indata_arm_&i where not missing(&aeseq)),
                    %end;
                    &aesoc._ALL_FREQ = (select count(distinct &usubjid) from tmp_indata where not missing(&aeseq)),
                    &aesoc._ALL_TIME = (select count(&usubjid)          from tmp_indata where not missing(&aeseq))
                    ;
            update tmp_desc_at_least
                set %do i = 1 %to &arm_n;
                        &aedecod._G&i._FREQ = &aesoc._G&i._FREQ,
                        &aedecod._G&i._TIME = &aesoc._G&i._TIME,
                        G&i._FREQ           = &aesoc._G&i._FREQ,
                        G&i._TIME           = &aesoc._G&i._TIME,
                    %end;
                    &aedecod._ALL_FREQ = &aesoc._ALL_FREQ,
                    &aedecod._ALL_TIME = &aesoc._ALL_TIME,
                    ALL_FREQ           = &aesoc._ALL_FREQ,
                    ALL_TIME           = &aesoc._ALL_TIME
                    ;
            update tmp_desc_at_least
                set %do i = 1 %to &arm_n;
                        G&i._FREQ_RATE = G&i._FREQ / &&arm_&i._subj_n,
                        G&i._TIME_RATE = G&i._TIME / &&arm_&i._subj_n,
                    %end;
                    ALL_FREQ_RATE = ALL_FREQ / &subj_n,
                    ALL_TIME_RATE = ALL_TIME / &subj_n
                    ;
            %if %superq(at_least_output_if_zero) = FALSE %then %do;
                delete from tmp_desc_at_least where ALL_FREQ = 0;
            %end;
        quit;
    %end;

    /*统计各组和合计发生的不良事件的例数和例次*/
    proc sql noprint;
        create table tmp_desc_arm as select * from tmp_base;
        update tmp_desc_arm
            set %do i = 1 %to &arm_n;
                    &aesoc._G&i._FREQ   = (select count(distinct &usubjid) from tmp_indata_arm_&i where not missing(&aeseq) and tmp_indata_arm_&i..&aesoc = tmp_desc_arm.&aesoc),
                    &aesoc._G&i._TIME   = (select count(&usubjid)          from tmp_indata_arm_&i where not missing(&aeseq) and tmp_indata_arm_&i..&aesoc = tmp_desc_arm.&aesoc),
                    &aedecod._G&i._FREQ = (select count(distinct &usubjid) from tmp_indata_arm_&i where not missing(&aeseq) and tmp_indata_arm_&i..&aesoc = tmp_desc_arm.&aesoc and tmp_indata_arm_&i..&aedecod = tmp_desc_arm.&aedecod),
                    &aedecod._G&i._TIME = (select count(&usubjid)          from tmp_indata_arm_&i where not missing(&aeseq) and tmp_indata_arm_&i..&aesoc = tmp_desc_arm.&aesoc and tmp_indata_arm_&i..&aedecod = tmp_desc_arm.&aedecod),
                %end;
                &aesoc._ALL_FREQ   = (select count(distinct &usubjid) from tmp_indata where not missing(&aeseq) and tmp_indata.&aesoc = tmp_desc_arm.&aesoc),
                &aesoc._ALL_TIME   = (select count(&usubjid)          from tmp_indata where not missing(&aeseq) and tmp_indata.&aesoc = tmp_desc_arm.&aesoc),
                &aedecod._ALL_FREQ = (select count(distinct &usubjid) from tmp_indata where not missing(&aeseq) and tmp_indata.&aesoc = tmp_desc_arm.&aesoc and tmp_indata.&aedecod = tmp_desc_arm.&aedecod),
                &aedecod._ALL_TIME = (select count(&usubjid)          from tmp_indata where not missing(&aeseq) and tmp_indata.&aesoc = tmp_desc_arm.&aesoc and tmp_indata.&aedecod = tmp_desc_arm.&aedecod)
                ;
        update tmp_desc_arm
            set %do i = 1 %to &arm_n;
                    G&i._FREQ           = ifn(&aedecod._FLAG = 1, &aedecod._G&i._FREQ, ifn(&aesoc._FLAG = 1, &aesoc._G&i._FREQ, .)),
                    G&i._TIME           = ifn(&aedecod._FLAG = 1, &aedecod._G&i._TIME, ifn(&aesoc._FLAG = 1, &aesoc._G&i._TIME, .)),
                %end;
                ALL_FREQ           = ifn(&aedecod._FLAG = 1, &aedecod._ALL_FREQ, ifn(&aesoc._FLAG = 1, &aesoc._ALL_FREQ, .)),
                ALL_TIME           = ifn(&aedecod._FLAG = 1, &aedecod._ALL_TIME, ifn(&aesoc._FLAG = 1, &aesoc._ALL_TIME, .))
                ;
        update tmp_desc_arm
            set %do i = 1 %to &arm_n;
                    G&i._FREQ_RATE = G&i._FREQ / &&arm_&i._subj_n,
                    G&i._TIME_RATE = G&i._TIME / &&arm_&i._subj_n,
                %end;
                ALL_FREQ_RATE = ALL_FREQ / &subj_n,
                ALL_TIME_RATE = ALL_TIME / &subj_n
                ;
    quit;

    /*合并 tmp_desc_at_least 和 tmp_desc_arm*/
    data tmp_desc;
        SEQ = _n_;
        set %if %superq(at_least) = TRUE %then %do;
                tmp_desc_at_least
            %end;
                tmp_desc_arm;
    run;

    /*计算 P 值*/
    proc sql noprint;
        select count(*) into :obs_n from tmp_desc;
    quit;
    %if &obs_n > 0 and %superq(hypothesis) = TRUE %then %do;
        /*转置，将各组别发生不良事件的例数放在同一列上*/
        proc transpose data = tmp_desc out = tmp_contigency_subset_pos label = ARM;
            var %do i = 1 %to &arm_n; G&i._FREQ %end;;
            by SEQ;
        run;

        /*补齐各组别未发生不良事件的例数*/
        data tmp_contigency;
            set tmp_contigency_subset_pos(rename = (COL1 = FREQ));
            label ARM = "ARM";
            ARM = kscan(ARM, 1, "-");
            by SEQ;

            length STATUS $12;
            STATUS = "EXPOSED";
            output;
            %do i = 1 %to &arm_n;
                if _NAME_ = "G&i._FREQ" then FREQ = &&arm_&i._subj_n - FREQ;
            %end;
            STATUS = "NOT EXPOSED";
            output;
        run;

        /*检查所有 by 组都存在某一行或某一列的频数之和为零*/
        ods html close;
        ods output CrossTabFreqs = tmp_cross_tab_freqs(where = (_TYPE_ in ("01", "10")));
        proc freq data = tmp_contigency;
            tables ARM * STATUS;
            weight FREQ /zeros;
            by SEQ;
        run;
        ods html;

        proc sql noprint;
            select count(distinct SEQ) into :by_n                     from tmp_cross_tab_freqs;
            select count(distinct SEQ) into :by_n_any_row_or_col_eq_0 from tmp_cross_tab_freqs where Frequency = 0;
        quit;

        /*如果存在某个 by 组各行各列频数之和均大于零，则可以进行假设检验*/
        %if &by_n ^= &by_n_any_row_or_col_eq_0 %then %do;
            ods html close;
            ods output ChiSq        = tmp_chisq(where = (Statistic = "卡方"))
                       FishersExact = tmp_fishers_exact(where = (Name1 = "XP2_FISH"));
            proc freq data = tmp_contigency;
                tables ARM * STATUS /chisq(warn = output);
                exact fisher;
                weight FREQ /zeros;
                by SEQ;
            run;
            ods html;

            proc sql noprint;
                create table tmp_summary as
                    select
                        tmp_desc.*,
                        tmp_chisq.CHISQ                 as CHISQ         label = "卡方统计量",
                        tmp_chisq.CHISQ_PVALUE          as CHISQ_PVALUE  label = "卡方检验 P 值",
                        tmp_chisq.CHISQ_WARNING         as CHISQ_WARNING label = "卡方警告",
                        tmp_fishers_exact.FISHER_PVALUE as FISHER_PVALUE label = "精确检验 P 值",
                        ifn(CHISQ_WARNING = 1, FISHER_PVALUE, CHISQ_PVALUE)
                                                        as PVALUE        label = "P 值"
                    from tmp_desc left join tmp_chisq(rename = (Value = CHISQ Prob = CHISQ_PVALUE Warning = CHISQ_WARNING)) as tmp_chisq on tmp_desc.SEQ = tmp_chisq.SEQ
                                  left join tmp_fishers_exact(rename = (nValue1 = FISHER_PVALUE)) as tmp_fishers_exact                   on tmp_desc.SEQ = tmp_fishers_exact.SEQ;
            quit;
        %end;
        %else %do;
            data tmp_summary;
                set tmp_desc;
                PVALUE = .;
                label PVALUE = "P 值";
            run;
        %end;
        
        %let PVALUE_AVALIABLE = TRUE;
    %end;
    %else %do;
        data tmp_summary;
            set tmp_desc;
        run;

        %let PVALUE_AVALIABLE = FALSE;
    %end;

    /*应用 format*/
    proc sql noprint;
        create table tmp_summary_formated as
            select
                *,
                (case when &aesoc._FLAG = 0 then AT_LEAST
                      when &aesoc._FLAG = 1 then
                      (case when &aedecod._FLAG = 0 then &aesoc
                            when &aedecod._FLAG = 1 then "    " || &aedecod
                      end)
                end)                                                                                       as ITEM          label = "项目",
                %do i = 1 %to &arm_n;
                    ifc(not missing(G&i._FREQ_RATE), kstrip(put(G&i._FREQ_RATE, &format_rate)), "-")                as G&i._FREQ_RATE_FMT label = %unquote(%str(%')%superq(arm_&i)-例数率（C）%str(%')),
                    kstrip(put(G&i._FREQ, &format_freq)) || "(" || kstrip(calculated G&i._FREQ_RATE_FMT) || ")"     as G&i._VALUE1        label = %unquote(%str(%')%superq(arm_&i)-例数（率）%str(%')),
                    %if &output_time_rate = TRUE %then %do;
                        ifc(not missing(G&i._TIME_RATE, kstrip(put(G&i._TIME_RATE, &format_rate)), "-"_             as G&i._TIME_RATE_FMT label = %unquote(%str(%')%superq(arm_&i)-例次率（C）%str(%')) %bquote(,)
                        kstrip(put(G&i._TIME, &format_freq)) || "(" || kstrip(calculated G&i._TIME_RATE_FMT) || ")" as G&i._VALUE2        label = %unquote(%str(%')%superq(arm_&i)-例次（率）%str(%'))  %bquote(,)
                    %end;
                    %else %do;
                        kstrip(put(G&i._TIME, &format_freq))                                                        as G&i._VALUE2        label = %unquote(%str(%')%superq(arm_&i)-例次%str(%')) %bquote(,)
                    %end;
                %end;
                ifc(not missing(ALL_FREQ_RATE), kstrip(put(ALL_FREQ_RATE, &format_rate)), "-")                      as ALL_FREQ_RATE_FMT  label = %unquote(%str(%')合计-例数率（C）%str(%')),
                kstrip(put(ALL_FREQ, &format_freq)) || "(" || kstrip(calculated ALL_FREQ_RATE_FMT) || ")"           as ALL_VALUE1         label = %unquote(%str(%')合计-例数（率）%str(%')),
                %if &output_time_rate = TRUE %then %do;
                    ifc(not missing(ALL_TIME_RATE), kstrip(put(ALL_TIME_RATE, &format_rate)), "-")                  as ALL_TIME_RATE_FMT  label = %unquote(%str(%')合计-例次率（C）%str(%')) %bquote(,)
                    kstrip(put(ALL_TIME, &format_freq)) || "(" || kstrip(calculated ALL_TIME_RATE_FMT) || ")"       as ALL_VALUE2         label = %unquote(%str(%')合计-例次（率）%str(%'))
                %end;
                %else %do;
                    kstrip(put(ALL_TIME, &format_freq))                                                        as ALL_VALUE2        label = %unquote(%str(%')合计-例次%str(%'))
                %end;
                %if &PVALUE_AVALIABLE = TRUE %then %do;
                    %bquote(,)
                    ifc(not missing(PVALUE), kstrip(put(PVALUE, &format_p)) || ifc(. < PVALUE < 0.05, "&significance_marker", ""), "")
                                                                                                           as PVALUE_FMT    label = "P值"
                %end;
            from tmp_summary;
    quit;

    /*排序*/
    proc sql noprint %if %bquote(&sort_linguistic) = %upcase(true) %then %do; sortseq = linguistic %end;;
        create table tmp_summary_formated_sorted as
            select * from tmp_summary_formated
            order by &aesoc._FLAG,
                     &aesoc._UNENCODED_FLAG,
                     %do i = 1 %to &sort_by_part_n;
                         &aesoc._&&sort_by_part_&i._arm._&&sort_by_part_&i._stat &&sort_by_part_&i._direction,
                     %end;
                     &aesoc,
                     &aedecod._FLAG,
                     &aedecod._UNENCODED_FLAG,
                     %do i = 1 %to &sort_by_part_n;
                         &aedecod._&&sort_by_part_&i._arm._&&sort_by_part_&i._stat &&sort_by_part_&i._direction,
                     %end;
                     &aedecod
                     ;
    quit;

    /*输出数据集*/
    data &outdata;
        set tmp_summary_formated_sorted;
        keep ITEM
             %do i = 1 %to &arm_n;
                 G&i._VALUE1
                 G&i._VALUE2
             %end;
             ALL_VALUE1
             ALL_VALUE2
             %if &PVALUE_AVALIABLE = TRUE %then %do;
                PVALUE_FMT
             %end;
             ;
    run;

    /*删除中间数据集*/
    %if %bquote(&debug) = %upcase(false) %then %do;
        proc datasets library = work nowarn noprint;
            delete tmp_arm_by_fmt
                   tmp_arm_sorted
                   tmp_indata
                   %do i = 1 %to &arm_n;
                       tmp_indata_arm_&i
                   %end;
                   tmp_indata_subset
                   tmp_base
                   tmp_desc_at_least
                   tmp_desc_arm
                   tmp_desc
                   tmp_contigency_subset_pos
                   tmp_contigency
                   tmp_cross_tab_freqs
                   tmp_chisq
                   tmp_fishers_exact
                   tmp_summary
                   tmp_summary_formated
                   tmp_summary_formated_sorted
                   ;
        quit;
    %end;

    %exit:
    %put NOTE: 宏程序 ass2 已结束运行！;
%mend;

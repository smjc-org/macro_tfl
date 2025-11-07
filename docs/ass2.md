# %ass2

## 简介

按系统器官分类、首选术语汇总不良事件。

## 语法

### 参数

#### 必选参数

- [indata](#indata)
- [outdata](#outdata)

#### 可选参数

- [aesoc](#aesoc)
- [aedecod](#aedecod)
- [aeseq](#aeseq)
- [usubjid](#usubjid)
- [arm](#arm)
- [arm_by](#arm_by)
- [sort_by](#sort_by)
- [sort_linguistic](#sort_linguistic)
- [at_least](#at_least)
- [at_least_text](#at_least_text)
- [at_least_output_if_zero](#at_least_output_if_zero)
- [unencoded_text](#unencoded_text)
- [hypothesis](#hypothesis)
- [format_freq](#format_freq)
- [format_rate](#format_rate)
- [format_p](#format_p)
- [significance_marker](#significance_marker)
- [output_time_rate](#output_time_rate)

#### 调试参数

- [debug](#debug)

### 参数说明

#### indata

**Syntax** : _data-set-name_<(_data-set-option_)>

指定待分析的数据集，可使用数据集选项。

> [!IMPORTANT]
>
> `indata` 数据集必须包含所有安全性集的受试者和不良事件序号 [aeseq](#aeseq)，对于未发生不良事件的受试者，其不良事件序号 [aeseq](#aeseq) 应为空。

> [!TIP]
>
> 你可以参考下面的代码创建符合分析要求的数据集
>
> ```sas
> data analysis;
>     merge adam.adsl adam.adae;
>     by usubjid;
>     if saffl = "Y";
> run;
> ```

> [!IMPORTANT]
>
> 如需对不良事件中的某个子集进行分析，例如，汇总与试验医疗器械相关的不良事件，你应当先筛选 `aereldfl = "Y"`，再与 `adam.adsl` 合并：
>
> ```sas
> data analysis;
>   merge adam.adsl adam.adae(where = (aereldfl = "Y"));
>   by usubjid;
>   if saffl = "Y";
> run;
> ```
>
> 先与 `adam.adsl` 合并，再筛选 `aereldfl = "Y"` 的做法是错误的：
>
> ```sas
> data analysis;
>   merge adam.adsl adam.adae;
>   by usubjid;
>   if saffl = "Y" and aereldfl = "Y";
> run;
> ```

**Usage** :

```sas
indata = analysis
```

---

#### outdata

**Syntax** : _data-set-name_<(_data-set-option_)>

指定保存汇总结果的数据集，可使用数据集选项。

汇总结果的数据集包含以下变量：

| 变量名       | 含义                       |
| ------------ | -------------------------- |
| ITEM         | 系统器官分类、首选术语名称 |
| G*x*\_VALUE1 | 组别 _x_ 例数（率）        |
| G*x*\_VALUE2 | 组别 _x_ 例次              |
| ALL_VALUE1   | 合计例数（率）             |
| ALL_VALUE2   | 合计例次                   |
| PVALUE_FMT   | P 值                       |

> [!NOTE]
>
> 变量 `PVALUE_FMT` 仅在指定 [hypothesis](#hypothesis) = `true` 时才会输出。

> [!TIP]
>
> 如果不需要输出合计汇总结果，可指定数据集选项 `drop = ALL_:`。

**Usage** :

```sas
outdata = t_7_3_6
```

---

#### aesoc

**Syntax** : _variable_

指定变量 `系统器官分类` 。

**Default** : `aesoc`

**Usage** :

```sas
aesoc = aebodsys
```

---

#### aedecod

**Syntax** : _variable_

指定变量 `首选术语` 。

**Default** : `aedecod`

**Usage** :

```sas
aedecod = aept
```

---

#### aeseq

**Syntax** : _variable_

指定变量 `不良事件序号` 。

> [!IMPORTANT]
>
> 对于发生了不良事件的观测，`aeseq` 不能是缺失值，但 [aesoc](#aesoc) 和 [aedecod](#aedecod) 可以是缺失值。

**Default** : `aeseq`

**Usage** :

```sas
aeseq = recrep
```

---

#### usubjid

**Syntax** : _variable_

指定变量 `受试者唯一编号` 。

**Default** : `usubjid`

**Usage** :

```sas
usubjid = usubjid
```

---

#### arm

**Syntax** : _variable_ | `#null`

指定变量 `试验组别` 。

**Default** : `#null`

默认情况下，将 [indata](#indata) 视为单组试验的数据集进行汇总。

**Usage** :

```sas
arm = arm
```

---

#### arm_by

**Syntax** :

- _variable_<(asc | desc \<ending>)>
- _format_<(asc | desc \<ending>)>
- `#null`

指定 [arm](#arm) 的排序方式。

> [!IMPORTANT]
>
> 1. 当指定一个变量 _`variable`_ 进行排序时，将按照 _`variable`_ 对 [arm](#arm) 各水平名称进行排序
> 2. 当指定一个输出格式 _`format`_ 进行排序时，将按照 _`format`_ 定义中的 _`value-or-range`_ 和 _`formatted-value`_ 的对应关系对 [arm](#arm) 各水平名称进行排序。_`format`_ 可以通过以下语句定义：
>
>    ```sas
>    proc format;
>        value armn
>            1 = "试验组"
>            2 = "对照组";
>    quit;
>    ```
>
> 3. `asc`, `ascending` 表示正向排序，`desc`, `descending` 表示逆向排序。

**Default** : `%nrstr(&arm)`

默认情况下，若 `arm = #null`，则将 [indata](#indata) 视为单组试验的数据集进行汇总，此时无需排序；若 `arm = ` _variable_，则根据 [arm](#arm) 自身的值排序。

**Usage** :

```sas
arm_by = arm(desc)
arm_by = armn.
```

---

#### sort_by

**Syntax** : <#G*number*>#<freq | time><(asc | desc \<ending>)>, ...

指定 [outdata](#outdata) 中观测的排序方式。

- #G*number* 表示按照第 _number_ 个组别排序，省略 #G*number* 表示按照合计结果排序，组别的 _number_ 值是由 [arm_by](#arm_by) 决定的。
- `freq` 表示按照频数排序，`time` 表示按照频次排序。
- `asc`, `ascending` 表示正向排序，`desc`, `descending` 表示逆向排序。

具体用法举例说明如下：

- `#FREQ(desc)` : 按照合计频数逆向排序。
- `#FREQ(desc) #TIME(asc)` : 按照合计频数逆向、合计频次正向排序。
- `#FREQ(desc) #G1#FREQ(desc)` : 按照合计频数逆向、第一个组别的频数逆向排序。
- `#G1#FREQ(desc) #G1#TIME(desc)` : 按照第一个组别的频数逆向、第一个组别的频次逆向排序。
- `#G1#FREQ(desc) #G2#TIME(desc)` : 按照第一个组别的频数逆向、第二个组别的频次逆向排序。
- `#G1#FREQ(desc) #G1#TIME(desc) #G2#FREQ(asc) #G2#TIME(asc)` : 按照第一个组别的频数逆向、第一个组别的频次逆向、第二个组别的频数正向、第二个组别的频次正向排序。
- `#G1#FREQ(desc) #G2#FREQ(asc) #G1#TIME(desc) #G2#TIME(asc)` : 按照第一个组别的频数逆向、第二个组别的频数正向、第一个组别的频次逆向、第二个组别的频次正向排序。

> [!IMPORTANT]
>
> - 单组试验不能指定 #G*number*
> - #G*number* 中的 _number_ 值不能超出由 [arm](#arm) 和 [arm_by](#arm_by) 限定的组别数量

**Default** : `#FREQ(desc) #TIME(desc)`

**Usage** :

```sas
sort_by = %str(#G1#FREQ(desc) #G1#TIME(desc) #G2#FREQ(desc) #G2#TIME(desc))
```

---

#### sort_linguistic

**Syntax** : `true` | `false`

指定是否在排序时遵循当前区域设置的默认 collating sequence 选项。

> [!NOTE]
>
> 指定 `sort_linguistic = true` 相当于指定了 `PROC SQL` 语句的 [SORTSEQ = LINGUISTIC](https://documentation.sas.com/doc/zh-CN/pgmsascdc/9.4_3.5/sqlproc/p12ohgh32ffm6un13s7l2d5p9c8y.htm#p0i5z6z3vnmjd2n1abnsp9p3bc05) 选项。

**Default** : `true`

**Usage** :

```sas
sort_linguistic = false
```

---

#### at_least

**Syntax** : `true` | `false`

指定是否在 [outdata](#outdata) 的第一行输出 `至少发生一次不良事件` 的汇总结果。

**Default** : `true`

**Usage** :

```sas
at_least = false
```

---

#### at_least_text

**Syntax** : _string_

指定当 `at_least = true` 时，[outdata](#outdata) 的第一行显示的描述性文本。

**Default** : `至少发生一次AE`

**Usage** :

```sas
at_least_text = %str(至少发生一次不良事件)
```

---

#### at_least_output_if_zero

**Syntax** : `true` | `false`

指定当 `至少发生一次不良事件` 的合计例数为零时，是否仍然在 [outdata](#outdata) 的第一行输出 `至少发生一次不良事件` 的汇总结果。

**Default** : `false`

```sas
at_least_output_if_zero = true
```

---

#### unencoded_text

**Syntax** : _string_

指定当出现未编码的不良事件（[aesoc](#aesoc) 或 [aedecod](#aedecod) 缺失）时，[outdata](#outdata) 显示的替代字符串。

> [!IMPORTANT]
>
> - [aesoc](#aesoc) 的 `未编码` 条目的汇总结果将在输出在 [outdata](#outdata) 的最后一行
> - [aedecod](#aedecod) 的 `未编码` 条目的汇总结果将输出在 [outdata](#outdata) 中对应 [aesoc](#aesoc) 内的最后一行

**Default** : `未编码`

**Usage** :

```sas
unencoded_text = %str(未编码)
```

---

#### hypothesis

**Syntax** : `true` | `false`

指定是否进行假设检验。

> [!NOTE]
>
> - 当只有一个组别时，无法进行假设检验。
> - 当有两个或多个组别时，将进行卡方检验，若卡方检验不适用，则进行 Fisher 精确检验。

> [!WARNING]
>
> `hypothesis = true` 并不一定意味着 [outdata](#outdata) 数据集中一定会输出假设检验的 P 值，若某一 [aesoc](#aesoc) 和 [aedecod](#aedecod) 的组合在指定的组别中均未发生，则列联表中存在某一行或某一列频数之和为零的情况，此时假设检验无法进行，程序将仅输出统计描述的结果。

**Default** : `true`

**Usage** :

```sas
hypothesis = false
```

---

#### format_freq

**Syntax** : _format_

指定频数和频次的输出格式。

**Default** : `best12.`

**Usage** :

```sas
format_freq = 8.
```

---

#### format_rate

**Syntax** : _format_

指定率的输出格式。

**Default** : `percentn9.2`

**Usage** :

```sas
format_rate = 8.3
```

---

#### format_p

**Syntax** : _format_

指定 P 值的输出格式。

**Default** : `pvalue6.4`

**Usage** :

```sas
format_p = spvalue.
```

---

#### significance_marker

**Syntax** : _character_

指定假设检验 P < 0.05 时，在输出结果中额外添加的标记字符。例如，指定 `significance_marker = %str(*)` 时，若 P = 0.0023，将显示为 `0.0023*`。

**Default** : `*`

**Usage** :

```sas
significance_marker = %str(*)
```

---

#### output_time_rate

**Syntax** : `true` | `false`

指定是否输出例次率。

例次率 = 例次 / 总例数 × 100%。

**Default** : `false`

---

#### debug

**Syntax** : `true` | `false`

指定是否删除中间过程生成的数据集。

**Default** : `false`

> [!NOTE]
>
> 这是一个用于开发者调试的参数，通常不需要关注。

# %reg_pb

## 简介

Passing-Bablok 回归，计算斜率和截距，及其 95% 置信区间。

## 语法

### 参数

#### 必选参数

- [indata](#indata)
- [outdata](#outdata)
- [x](#x)
- [y](#y)

#### 可选参数

- [alpha](#alpha)
- [format](#format)

#### 调试参数

- [debug](#debug)

### 参数说明

#### indata

**Syntax** : _data-set-name_<(_data-set-option_)>

指定待分析的数据集，可使用数据集选项。

**Usage** :

```sas
indata = adeff
```

---

#### outdata

**Syntax** : _data-set-name_<(_data-set-option_)>

指定保存汇总结果的数据集，可使用数据集选项。

汇总结果的数据集包含以下变量：

| 变量名         | 含义        |
| -------------- | ----------- |
| _param_        | 参数        |
| _desc_         | 参数描述    |
| _estimate_     | 估计值      |
| _lower_        | 下限        |
| _upper_        | 上限        |
| _estimate_fmt_ | 估计值（C） |
| _lower_fmt_    | 下限（C）   |
| _upper_fmt_    | 上限（C）   |

**Usage** :

```sas
outdata = t_5_4_1_2
```

---

#### x

**Syntax** : _variable_

指定 x 轴变量，在体外诊断试剂临床试验中，通常是对比试剂检测结果。

**Default** : `crcd1`

**Usage** :

```sas
x = crcd1
```

---

#### y

**Syntax** : _variable_

指定 y 轴变量，在体外诊断试剂临床试验中，通常是考核试剂检测结果。

**Default** : `trcd1`

**Usage** :

```sas
y = trcd1
```

---

#### alpha

**Syntax**: _numeric_

指定显著性水平。

**Default** : `0.05`

**Usage** :

```sas
alpha = 0.05
```

---

#### format

**Syntax** : _format_

指定估计值和置信区间上下限的输出格式。

**Default** : `8.4`

**Usage** :

```sas
format_freq = percentn9.2
```

---

#### debug

**Syntax** : `true` | `false`

指定是否启用调试模式。

**Default** : `false`

> [!NOTE]
>
> 这是一个用于开发者调试的参数，通常不需要关注。

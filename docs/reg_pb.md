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

## Passing-Bablok 回归算法

1. 设样本数量为 $n$ ，任取两个样本 $(x_i, y_i)$ 和 $(x_j, y_j)$ ，构成一个点对子，每个点对子的连线都有一个斜率 $S_{ij}$

   $$
   S_{ij} = \frac{y_i - y_j}{x_i - x_j} \ \ , 1 \le i < j \le n
   $$

   这样的点对子一共有 $\mathrm{C}_n^2$ 个。

2. 以下两种点对子需要排除，它们对 Passing-Bablok 回归对参数的估计不作贡献。
   - 重合的点对子，即 $x_i = x_j$ 且 $y_i = y_j$ ；
   - 斜率为 -1 的点对子，即 $S_{ij} = -1$ ；

   记剩余样本数量为 $M$ 。

3. 对 $M$ 个点对子按照斜率从小到大排序，得到序列 $S_{(1)} \le S_{(2)} \le \cdots \le S_{(M)}$ 。
   对于斜率不存在的点对子，处理方式如下：
   - 若 $x_i = x_j$ 且 $y_i \gt y_j$ ，则 $S_{ij} = +\infty$ ，将该点对子排在序列最前；
   - 若 $x_i = x_j$ 且 $y_i \lt y_j$ ，则 $S_{ij} = -\infty$ ，将该点对子排在序列最后。

4. 计 $S_{ij} \lt -1$ 的点对子数量为 $K$ ，称作“偏移量”，Passing-Bablok 回归的斜率 $b$ 可以通过序列 $S_{(i)}$ 的偏移中位数来估计：

   $$
   b =
   \begin{cases}
   S_{\left(\frac{M + 1}{2} + K\right)}, & \text{if } M \text{ is odd} \\
   \frac{1}{2} \cdot \left( S_{\left(\frac{M}{2} + K\right)} + S_{\left(\frac{M}{2} + 1 + K\right)}\right), & \text{if } M \text{ is even} \\
   \end{cases}
   $$

5. 估计 $b$ 的置信区间

   $$
   C = Z_{1 - \alpha/2} \sqrt{\frac{n(n - 1)(2n + 5)}{18}}
   $$

   其中 $Z_{1 - \alpha/2}$ 为标准正态分布的 $ 1 - \alpha/2$ 分位数。

   $$
   M_1 = \frac{M - C}{2}, \ \ M_2 = M - M_1 + 1
   $$

   其中， $M_1$ 需要舍入到最接近的整数值。

   $b$ 的置信区间为：

   $$
   S_{(M_1 + K)} \le b \le S_{(M_2 + K)}
   $$

6. 估计截距 $a$ 及其置信区间

   截距 $a$ 的估计原理是：至少有一半的点在线 $y = a + bx$ 的上方，另一半则在线 $y = a + bx$ 的下方。

   假设每个点都能落在线 $y = a + bx$ 上，进而对每个点，都能计算一个截距 $a_i = y_i - bx_i$ ，所有 $a_i$ 从小到大排序，取中位数，即可得到截距 $a$ 的估计值：

   $$
   a = \text{median}\{y_i - bx_i\}
   $$

   截距 $a$ 的置信区间为：

   $$
   a_L = \text{median}\{y_i - b_Ux_i\} \\
   a_U = \text{median}\{y_i - b_Lx_i\}
   $$

## References

1. Passing H, Bablok W. A new biometrical procedure for testing the equality of measurements from two different analytical methods. Application of linear regression procedures for method comparison studies in clinical chemistry, Part I[J]. Clinical Chemistry and Laboratory Medicine, 1983, 21(11): 709-720.

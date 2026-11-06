# 非线性约束优化三种求解方案的比较

本项目采用 [MIT许可证](https://github.com/hyzf12321/constrained-optimization-matlab/blob/main/LICENSE)，版权署名为 hyzf12321（2026年）。

使用 MATLAB 比较外罚函数法＋BFGS、外罚函数法＋粒子群优化（PSO）及复合形方案。三个问题依次考察基础非线性不等式约束、六维非凸多峰搜索，以及带非线性等式的混合约束。

两种外罚方案共用约束处理框架，比较不同搜索方法；复合形方案提供直接约束搜索的对照。比较对象是包含预处理、重启和恢复步骤的完整方案。

当前配置每题每法30次，全部270个输出满足原约束；目标精度达标次数分别为：A题30/30、30/30、28/30，B题18/30、30/30、26/30，G05三法均30/30。

## 文件与运行

```text
coursework_main.m                 模型、算法、实验、自检、统计和历史绘图
plot_public_results.m             重建本页四组公开图表
02_MATLAB验证/
  coursework_problem.m            独立模型与解析导数
  quadratic_penalty.m             独立二次罚函数实现
  verify_models.m                 独立模型/导数与fmincon交叉核查
03_验证结果/
  coursework_results.mat          从Release单独下载的完整结果库（不随Git提交）
figures/                          四组主要结果图
README.md
```

先下载或克隆代码，再到本仓库的 [Releases页面](https://github.com/hyzf12321/constrained-optimization-matlab/releases) 下载附件 `coursework_results.mat`。将文件保存为仓库根目录下的 `03_验证结果/coursework_results.mat`。

项目在 MATLAB R2023b 中验证。核心求解、统计和绘图可用基础 MATLAB 运行。独立交叉核查脚本 `verify_models` 使用 Optimization Toolbox 中的 `fmincon`。在仓库根目录执行 `coursework_main('summary_cost')` 查看当前结果，执行 `coursework_main('selftest')` 运行 60 项自检，执行 `plot_public_results` 重建图表。

```matlab
coursework_main('summary_cost');      % 当前推荐配置，直接读取已有结果
plot_public_results;                  % 重建四组PNG，不重新优化、不改MAT
tests = coursework_main('selftest');  % 模型、算法、预算、坐标变换等60项自检
assert(all([tests.Passed]));

% 可选：读取历史阶段，均不重新求解
coursework_main('summary3');          % 原始370组正式/补充实验
coursework_main('summary_improved');  % 高预算改进及配对对照

% 可选：独立交叉核查，需要Optimization Toolbox，会产生核查输出
addpath('02_MATLAB验证');
verify_models;
```

`round1`、`round2`、`complex` 等历史实验入口会写入数据，默认入口执行 `round1`。`round3`、`improve` 和 `cost_review` 会返回已完成批次的保存结果。探索新参数或种子时，在独立工作副本中运行。

公开结果库约 248 MB，通过 Release 单独下载。`plot_public_results` 从结果库读取数据，并将四组图片保存到 `figures`。历史绘图入口 `plot3`、`plot_improved` 和 `plot_cost` 使用 `90_临时文件` 作为输出目录。

## 问题模型与参考值

统一采用 $`\min f(x)`$，$`g(x)\le0`$，$`h(x)=0`$。代码内部用 `C` 表示G05。

### A：二维课内题

$$
\min_{u,v} f_A=(u-2)^2+v^2,\qquad -u\le0,\ -v\le0,\ u^2+v-1\le0.
$$

A 题取自课程“约束优化”中的 K-T 条件例题。目标是最小化 $`(u-2)^2+v^2`$，约束为 $`u\ge0`$、$`v\ge0`$ 和 $`u^2+v\le1`$。由 $`0\le u\le1`$ 可知目标值至少为 1，且仅在 $`(1,0)`$ 处达到。计算边界为 $`[-1,2]^2`$，覆盖完整可行域。

### B：自建六维非凸耦合扩展

变量顺序为 $`(u_1,v_1,u_2,v_2,u_3,v_3)`$。

$$
\begin{aligned}
\min F={}&\sum_{i=1}^3\big[(u_i-2)^2+v_i^2+\sin^2(3\pi u_i)\big]\\
&+5\sum_{i=1}^2\big[(u_i-u_{i+1})^2+(v_i-v_{i+1})^2\big],
\end{aligned}
$$

每组约束均为 $`-u_i\le0`$、$`-v_i\le0`$、$`u_i^2+v_i-1\le0`$。计算边界为 $`[-1,2]^6`$。

三组基础目标分别至少为1，其余各项非负，因此全局参考值为3，唯一全局解为 $`(1,0,1,0,1,0)`$。正弦项引入非凸多峰性，耦合项连接各变量组。B 题由项目构造。判断运行是否达标时，直接将原目标值与已推导的全局参考值 3 比较。

### G05：四变量混合约束基准

模型来自 CEC 2006 技术报告。

$$
\min f=3x_1+10^{-6}x_1^3+2x_2+\frac{2\times10^{-6}}3x_2^3.
$$

不等式为 $`x_3-x_4-0.55\le0`$、$`x_4-x_3-0.55\le0`$。三条非线性等式如下。

$$
\begin{aligned}
1000\sin(-x_3-0.25)+1000\sin(-x_4-0.25)+894.8-x_1&=0,\\
1000\sin(x_3-0.25)+1000\sin(x_3-x_4-0.25)+894.8-x_2&=0,\\
1000\sin(x_4-0.25)+1000\sin(x_4-x_3-0.25)+1294.8&=0.
\end{aligned}
$$

边界为 $`0\le x_1,x_2\le1200`$、$`-0.55\le x_3,x_4\le0.55`$，角度采用弧度。严格等式数值参考目标为 `5126.49810959527`，参考向量约为 `[679.9453207360568;1026.0671316649825;0.1188763638621132;-0.396233553502708]`。

CEC 容差带允许等式残差，参考目标为 `5126.4967140071`。

## 方法与实验配置

两种外罚方案采用相同的变量归一化和尺度设置。罚函数对等式残差和不等式违反量施加二次惩罚。

$$
\phi=f/s_f+r\left[\sum_j\max(0,c_j)^2+\sum_k e_k^2\right],\quad
c=[g/s_g;-z;z-1],\quad e=h/s_h.
$$

目标尺度A/B/G05分别为1、3、10000；不等式尺度均为1，G05等式尺度为1000。11层罚系数从1至 $`10^{10}`$。G05另共同加入边界外四次保护项，避免三次目标在远处压过二次罚项；原边界内该项和梯度均为0。

- 外罚＋BFGS：解析目标梯度与约束Jacobian，强Wolfe线搜索，`c1=1e-4`、`c2=0.9`。B题当前固定12起点，每起点最多7500次，总上限90000。
- 外罚＋PSO：40粒子，惯性0.9至0.4，学习系数1.7；通过共同罚函数处理边界，无额外位置截断。G05当前总预算12000，实际11990次。
- 复合形方案：反射、收缩、次坏点尝试。A题保留基本单起点配置；B题使用约束几何投影＋固定2起点，每起点最多2343次；G05使用只依据约束的等式恢复，目标优化仍由复合形搜索完成。

G05的两种外罚方案共用残差坐标预处理：原边界内搜索坐标为 $`[z_3,h_1/1000,h_2/1000,h_3/1000]`$，边界外有可逆的一阶连续延拓。搜索在四个坐标上独立进行，三个等式残差作为搜索变量进入外罚函数。该坐标设计利用了 G05 的约束结构。

A、B 和 G05 的联合评价预算上限分别为 100000、300000 和 500000。初始化、失败试探、重启、恢复和坐标转换中的模型调用均计入联合评价。另行记录解析导数、差分 Jacobian、投影迭代与耗时，以区分调用次数和计算开销。

### 种子与验收

当前正式种子固定为 `2026102901:2026102930`，同题方法间配对。开发、留出和正式结果分开统计，正式达标次数不用于选择配置。B题重启开发使用10个旧种子，在候选中选首个达到8/10的最小起点数；全新留出种子为 `2026102831:2026102835`。G05 PSO在5个开发种子上比较3000/6000/12000/24000预算，按预定门槛选12000，再做独立留出验证。

达标同时要求原始不等式违反量不超过 `1e-6`、边界违反量不超过 `1e-8`，G05原始等式残差不超过 `1e-4`，并满足目标绝对误差A/B不超过 `1e-4`、G05不超过 `1e-2`。G05额外统计 `1e-6` 等式严格诊断。

## 当前结果与分析

每种组合运行 30 次。目标误差以各题的原目标参考值计算，耗时以秒计。

| 问题 | 方法 | 达标次数 | 误差中位数 | 误差均值 | 最坏误差 | 联合评价中位数 | 求解耗时中位数 |
|---|---|---:|---:|---:|---:|---:|---:|
| A | 外罚＋BFGS | 30/30 | 1.00e-6 | 1.00e-6 | 1.00e-6 | 446 | 0.01810 |
| A | 外罚＋PSO | 30/30 | 1.00e-6 | 1.00e-6 | 1.00e-6 | 61415 | 0.92270 |
| A | 复合形 | 28/30 | 1.98e-8 | 0.01865 | 0.41903 | 279 | 0.004758 |
| B | 外罚＋BFGS，12起点 | 18/30 | 1.00e-6 | 0.54637 | 1.9922 | 2140.5 | 0.11469 |
| B | 外罚＋PSO | 30/30 | 1.00e-6 | 1.00e-6 | 1.00e-6 | 134112 | 2.44520 |
| B | 投影复合形，2起点 | 26/30 | 8.30e-7 | 0.17966 | 1.7292 | 2518.5 | 0.06471 |
| G05 | 外罚＋BFGS，残差坐标 | 30/30 | 3.30e-6 | 3.30e-6 | 3.30e-6 | 665.5 | 0.02415 |
| G05 | 外罚＋PSO，残差坐标 | 30/30 | 3.28e-7 | 3.30e-7 | 4.03e-7 | 11990 | 0.24176 |
| G05 | 复合形＋等式恢复 | 30/30 | 1.06e-5 | 1.06e-5 | 1.06e-5 | 6246.5 | 0.09313 |

九组合可行次数均为30/30，G05也全部通过额外严格等式诊断。目标精度未达标的运行集中在三种组合中。B 题外罚＋BFGS 有 12 次，B 题复合形有 4 次，A 题复合形有 2 次。

完整标准差、四分位距、最好/最坏值、导数和辅助处理成本见 `cost_review.summary_all`，逐次输出见 `cost_review.table_all`。

多起点耗时为实测子求解器耗时之和；B题当前配置由已保存的固定重启前缀得到，包装层时间没有重新测量，`wall_seconds=NaN`。耗时依赖运行机器，复现时重点核对数值、种子和评价次数。

### 四组主要图表

![当前配置30次目标误差分布](figures/01_objective_errors.png)

A 题复合形的联合评价中位数为 279，三种方案中最低，达标 28 次。B 题外罚＋PSO 达标 30 次，联合评价中位数为 134112，高于同题另外两种方案。

![当前配置的目标误差和约束违反轨迹](figures/02_convergence.png)

收敛轨迹采用正式列表中的首个种子 `2026102901`。横轴为累计联合评价次数，约束违反量按原始验收容差归一化。轨迹按保存的检查点记录，包括部分不可行试探点，首次达标时间的分辨率取决于检查点间隔。

![配对原方案、高预算改进和当前配置的质量与成本](figures/03_quality_cost.png)

G05 的外罚＋PSO 在原始批次达标 2/30，在新种子的配对基线中达标 1/30。同种子下，残差坐标高预算方案达标 30/30。当前低预算方案也达标 30/30，评价中位数由 499994 降至 11990。B 题外罚＋BFGS 在单起点、12 起点、40 起点配置下分别达标 3/30、18/30、30/30。投影复合形在 2 起点与 128 起点配置下分别达标 26/30 和 30/30。

![B题复合形投影与重启消融](figures/04_B_ablation.png)

B 题高预算消融使用相同的 10 个种子，预算上限为 300000。三种配置分别为投影加 128 起点、投影加单起点，以及无投影的 128 起点。几何投影依据约束构造可行点。

BFGS 利用导数信息，在 A 题和 G05 上以较少的联合评价达到目标精度。B 题的非凸结构使其结果对起点敏感。PSO 在 B 题的 30 次运行中均达标，代价是更多模型调用。复合形利用投影与等式恢复处理不同约束，部分运行在达到目标精度前因点集收缩或反射停滞而结束。

## 数据组织与公开副本

MAT 顶层变量 `coursework_results` 汇总各阶段的配置、逐次输出、统计和核查记录，其中包括历史未达标运行。

```matlab
s = load('03_验证结果/coursework_results.mat','coursework_results');
d = s.coursework_results;
b = d.improvement.batches{d.improvement.latest};
current_runs = [b.experiments(d.cost_review.existing_indices); d.cost_review.runs];
disp(d.cost_review.summary_all);  % 9行组合统计
disp(d.cost_review.table_all);    % 270行逐次结果
assert(numel(current_runs) == 270);
```

原第三轮保留270组主实验、60组多起点及40组敏感性补充。高预算改进另有440组验证/对照；当前配置的180组引用既有记录、B题60组采用固定重启前缀、G05新增30次低预算求解。

部分子运行轨迹为无损列式存储，带 `trace_storage='columns-v1'`、`trace_shapes` 和 `trace_size`；例如 `r.trace.evaluations`、`r.trace.f` 为按检查点拼接的字段矩阵。主程序自带解码，新绘图脚本兼容列式及逐点结构体格式。

公开副本将历史元数据中的本机项目路径改为相对路径。数值、种子、参数、轨迹和退出状态沿用原始记录。历史快照可用于追溯各批次所用的代码版本。

## 公开包核查

整理日期：2026-11-03。4个既有MATLAB文件与原文件逐一SHA-256一致；新增的绘图脚本及4个既有文件均通过Code Analyzer检查。已在本目录实际通过60项自检，读取当前和历史汇总，并从公开MAT重建、查看四组图片。

当前270个输出再次用独立模型计算原目标和约束，最大差异为0，逐次目标、评价次数及达标标记与保存表格一致，全部满足原始可行性标准。公开MAT保存后重载并以 `isequaln` 验证一致。

公开 MAT 共 247877748 字节。以下为文件的 SHA-256 校验值。

```text
37f9f8ee4eb481a609593cf92623e475b9358f2df450e8e8659d6d56bec50699
```

## 参考来源

- 课程讲义：约束优化中的K-T例题、外罚函数法、复合形法，无约束优化中的BFGS，以及Wolfe线搜索。
- Liang J J, Runarsson T P, Mezura-Montes E, et al. *Problem Definitions and Evaluation Criteria for the CEC 2006 Special Session on Constrained Real-Parameter Optimization*. 2006. [技术报告](https://al-roomi.org/multimedia/CEC_Database/CEC2006/CEC2006_TechnicalReport.pdf)：G05模型与评价背景。
- Kennedy J, Eberhart R. *Particle Swarm Optimization*. 1995. [原论文](https://staff.washington.edu/paymana/swarm/kennedy95-ijcnn.pdf)：PSO基本更新思想。另见 [MathWorks算法说明](https://www.mathworks.com/help/gads/particle-swarm-optimization-algorithm.html)。
- Runarsson T P, Yao X. *Stochastic Ranking for Constrained Evolutionary Optimization*. IEEE Transactions on Evolutionary Computation, 2000, 4(3): 284–294. [DOI](https://doi.org/10.1109/4235.873238)：等式容差与目标参考值解释。
- Spettel P, Ba Z, Arnold D V. *Active Sets for Explicitly Constrained Evolutionary Optimization*. Evolutionary Computation, 2022, 30(4): 531–553. [DOI](https://doi.org/10.1162/evco_a_00311)：严格等式数值参考的补充来源。

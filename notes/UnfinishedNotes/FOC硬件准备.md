# FOC硬件准备

## 编码器

### 编码器分类

#### 一、按工作原理分类

##### 1. **光电编码器**

- **原理**：通过光源照射刻线码盘，由光电传感器接收通断光信号，转换为电脉冲或数字信号。
- **优点**：
  - 分辨率高（可达每转10,000线以上），精度优异；
  - 响应速度快，动态性能强。
- **缺点**：
  - 抗污染能力弱：灰尘、油污易遮挡光路导致信号丢失；
  - 抗震性差：玻璃码盘易因振动或温度骤变破裂；
  - 寿命受限：LED光源存在老化问题（约数万小时）。
- **适用场景**：洁净环境中的高精度设备（如实验室仪器、半导体制造设备）。
##### 2. **磁电编码器**

- **原理**：利用磁敏元件（霍尔传感器）检测磁性码盘的磁场变化，输出位置信号。
- **优点**：
  - 抗恶劣环境：耐油污、粉尘、潮湿，甚至可水下工作；
  - 寿命长：无机械接触磨损。
- **缺点**：
  - 精度较低：易受电磁干扰（如电机磁场），温度漂移明显；
  - 分辨率受限（通常低于光电式）。
- **适用场景**：工程机械、汽车转向系统、户外设备等工业现场。

##### 3. **电容式编码器**

- **原理**：基于电容变化检测转子与定子间的纹路位移，通过ASIC芯片转换为数字信号。
- **优点**：
  - 抗干扰性强：对污染、振动不敏感，兼具高可靠性；
  - 功耗低（6–18 mA），适合电池供电设备；
  - 分辨率可编程：无需更换硬件即可调整分辨率。
- **缺点**：
  - 成本较高，技术较新，应用案例积累少于传统类型。
- **适用场景**：物联网（IoT）设备、便携仪器、需灵活配置的自动化系统。

#### 二、按信号输出方式分类

##### 1. 增量式编码器

- **原理**：输出相位差90°的A/B脉冲和每转一个的Z相零位脉冲，需外部计数器累计位置。
- **优点**：
  - 结构简单、成本低，抗干扰能力强；
  - 支持长距离传输（如HTL差分输出型）。
- **缺点**：
  - 断电位置丢失：需每次上电回零操作；
  - 无法直接获取绝对位置。
- **适用场景**：成本敏感且需实时速度反馈的应用（如变频电机调速、传送带控制）。

##### 2. 绝对式编码器

- **原理**：每个位置对应唯一二进制编码，直接输出绝对角度值149。
- **优点**：
  - 断电位置保留，无需重复校准；
  - 高可靠性，减少系统初始化时间。
- **缺点**：
  - 结构复杂，成本高（尤其多圈高分辨率型）；
  - 分辨率受码道数限制（例如16位编码器需16条码道）。
- **适用场景**：位置安全关键型设备（如电梯控制、风力发电机变桨系统）。

##### 3. 混合式编码器

- **原理**：结合增量与绝对输出，同时提供绝对位置和增量脉冲。
- **优点**：兼具断电位置保持与实时动态控制能力。
- **缺点**：接口复杂，成本高于单一类型。
- **适用场景**：高端伺服系统、机器人关节控制。

### 编码器芯片选择

编码器芯片选择AS5600，该芯片为非接触12bit磁角度位置传感器，且为绝对式编码器。该芯片适用于小型，低转速电机，且成本较低，易于使用

---

## 无刷电机

### BLDC和PSMS

BLDC(无刷直流电机)，PMSM(永磁同步电机) 。感应电动势波形为梯形波称为BLDC，当感应电动势波形为正弦波时称为PMSM。一般来说FOC使用PMSM电机会好一些，但对于学习来说BLDC应该也足够使用。

### 电机关键参数：

1. 额定转速：指电机在额定电压下的转速

2. 额定功率：指电机在额定转速下输出的额定功率

3. **KV值**：表示电机运行速度的指标，电机转速=KV值x工作电压。

4. 极、相和槽：槽数（Stator Slots）：定子上线圈绕组的数量。极数（Rotor Poles）：转子上的磁极对数，一个极对为一对南北磁极。

   1. 极数：极数表示旋转转子的永磁体极数，具有一对N极／S极的电机称为双极电机（从电机控制的角度来看，当极数增加一倍时，转速将减半，当极数增加四倍时，转速将减少四分之一，因此控制方法不取决于极数。）。

   2. 相：相表示固定定子的独立线圈数。３相电机是具有三个独立线圈且间隔120度的电机。

   3. 槽数：严密地讲，槽数是指定子中“凹槽”的空间数量，但在集中绕组（后续再简略讨论绕组方式）电机中，如图所示，是在每个齿上分别缠绕一组线圈。

      > 例如12N10P，N就是指槽数，P指极数。其中极数一定是**偶数**（磁极成对出现），３相电机的槽数是3的倍数。另外，P值与转速成反比，如果N>P，相对转速更高。N相等的电机，P越大，电机扭力越强。

   4. 常见极槽数：

      - 9槽/6极：较为平衡，结构紧凑
      - 12槽/8极：适合低速高扭矩
      - 18槽/16极：超平滑扭矩，适合伺服电机

5. 绕组方式：电机的定子绕组形式有两种

   1. 分布绕组（Distributed Winding）：绕组缠绕在至少两个定子齿上
   2. 集中绕组（Concentrated Winding）：绕组仅缠绕在一个定子齿上

   - 区别：分布式绕组的电机的反电动势电压呈正弦曲线，而集中式绕组的电机的反电动势电压呈梯形曲线。对于分布式绕组的电机，其转动都更加平滑或平顺，因此分布绕组的无刷电机通常适合做高精度伺服电机，但其成本通常也更高。对于分布式绕组，绕组的上端和下端重叠，电机的这个区域也称为绕组头，由于重叠，分布式绕组的绕组头比集中式绕组的绕组头大

### 电机型号选择

网上大多使用的是2804电机，一些网店上也有成品的电机加磁编码器的组合售卖，可以节省编码器部分制作的成本。为了节约硬件测试时间，~~绝对不是我没钱画板子或者懒~~，我打算直接购买成品套件先学习FOC软件部分( 其实还有《FOC软件准备》这篇博客在计划中 )

---

## MCU

对于主控芯片的选择要求非常少，主流的MCU例如STM32F1系列，STM32F4系列，ESP32系列等等。为了便于我这个初学者开发和调试，就是用最经典的stm32f103最小系统板好了，就在面包板上接线，后续如果真的投入实际使用再考虑画板子

---
title: IMU四元数解算
date: 2025-06-10 17:19:32
tags: ["Hardware", "Eular Angle", "Quaternion"]
categories: ["Hardware", "Sensor", "Sensor Drive"]
thumbnail: "/post_images/IMU四元数解算/机械IMU.jpeg"
mathjax: true
---

## 前言

{% notel yellow Warn %}
本文章有基础的理论推导，过程可能存在不严谨的地方，着重对四元数的**实际应用**做讨论
此文章的观点或代码仍有瑕疵，若您有更好的解决方案或更正建议欢迎留言讨论
{% endnotel %}
{% notel green  info %}
本文前部分是关于理论推导，内容比较枯燥。若只关注实际应用请跳转到后文，查阅[相关代码](#实际应用于代码中)
本文的代码已通过验证，MCU为AI8051，IMU为imu660ra。角速度通过死区 + 去静态零飘抑制。实际测试静态零漂约为0.046度/秒
{% endnotel %}

## 关于四元数的介绍和理解

### 四元数的产生

对于一个复数，可以写成如下形式
$$
\begin{align*}
z = \rho \cos \alpha + i \rho \sin \alpha
\end{align*}
$$
,运用欧拉公式(Euler's formula) $\rho e^{i \alpha} = \rho \cos \alpha + i \rho \sin \alpha$ 可将三角函数形式的复数转为指数形式 $z = \rho e ^ {i \alpha}$ 对该复平面内的向量进行旋转操作，假设旋转角度为$\phi$,则旋转过程如下: 

$$
\begin{align*}
z * e^{i \phi} = \rho e ^ {i \alpha} * e^{i \phi} = \rho e^{i (\alpha + \phi)}
\end{align*}
$$

该旋转为一个自由度下的变化，对于实际应用来说，一个物品在空间中的矢量有三个自由度。因此我们需要四个变量来描述角度的变化，其中一个实数变量表示旋转的角度大小，剩下三个为虚数，体现旋转轴的方向。我们将这样的四个变量记作： $q = (w,x,y,z)$ 对于一个旋转角度为*θ*的四元数可表示为：
$$
q = (\cos{\frac{\theta }{2} }, u_{x} \sin{\frac{\theta}{2}}, u_{y} \sin{\frac{\theta}{2}}, u_{z} \sin{\frac{\theta}{2}})
$$


- **实部（w）**：与旋转的角度相关，体现旋转的“量”。
- **虚部（x, y, z）**：与旋转轴的方向相关，体现旋转的“方向”。

为了方便，我们有时将其简写为：
$$
\begin{align*}
q = (w,\vec{v})
\end{align*}
$$
其中
$$
\begin{align*}
\vec{v} = (x, y, z)
\end{align*}
$$


这也就是我们常说的**轴角对**：

- **旋转轴**：一个单位向量，表示旋转的轴线方向。
- **旋转角**：一个标量，表示绕该轴旋转的角度。

## 用四元数表示3D旋转矩阵

并不是所有的四元数都能表示三维空间中的一个旋转，只有单位四元数才能正确表示一个旋转。所谓单位四元数即：
$$
\begin{align*}
q = (m,\vec{v}) = (w,x,y,x)(满足w^2 + x^2 + y^2 + z^2 = 1)
\end{align*}
$$
对一个3D向量：
$$
\begin{align*}
\vec{p} = (p_{x}, p_{y}, p_{z})
\end{align*}
$$
其旋转后的向量可表示为：
$$
\vec{p^{’}} = q.\vec{p}.q^{-1}
$$

### 计算旋转矩阵

**(1)计算q⋅p**

设：
$$
\begin{align*}
\vec{q} = w + xi + yj + zk, \quad \vec{p} = 0 + p_{x}i + p_{y}j + p_{z}k
\end{align*}
$$
则
$$
\begin{aligned}
\vec{q}.\vec{p} &= (w + xi + yj + zk)(0 + p_{x}i + + p_{y}j + p_{z}k)\\ 
                  &=(- xp_{x} - yp_{y} - zp_{z}) + (wp_{x} + yp_{z} - zp_{y})i + (wp_{y} + zp_{x} - xp_{z})j + (wp_{z} + xp_{y} - yp_{x})k
\end{aligned}
$$
记
$$
\begin{cases}
a = - xp_{x} - yp_{y} - zp_{z}	\\
b = wp_{x} + yp_{z} - zp_{y}  	\\
c = wp_{y} + zp_{x} - xp_{z}	   \\
d = wp_{z} + xp_{y} - yp_{x}
\end{cases}
$$
**(2) 计算 (q⋅p)⋅q−1**
$$
\begin{align*}
&\vec{q}^{-1} = w - xi - yj - zk,所以：\\
&(a + bi + cj + dk)(w - xi - yj - zk)\\
&展开后为：\\ 
&\left\{
\begin{aligned}
p^{’}_{x} = (-ax + bw - cz + dy)	\\
p^{’}_{y} = (-ay + bz + cw - dx)	\\
p^{’}_{z} = (-az - by + cx + dw)	\\
\end{aligned}
\right.
\end{align*}
$$
**(3)整理成矩阵形式**

将a,b,c,d代入上方程组中，可整理出**旋转矩阵**：
$$
\vec{p}^{’} = R\vec{p}	\\
R  = \begin{bmatrix}
 1 - 2y^{2} - 2z^{2} & 2xy - 2wz & 2xy + 2wz	\\
 2xy + 2wz & 1 - 2x^2 - 2z^2 & 2yz - 2wx \\
 2xz - 2wy & 2yz + 2wx & 1 - 2x^2 - 2y^2
\end{bmatrix}
$$
{% notel green  info %}
该旋转矩阵较为重要，在本文后续还会用到
{% endnotel %}

---

## 四元数的关键公式推导

1. 四元数和角速度的关系

   对于给定一个角速度，我们需要找到四元数如何随时间变化。角速度 *ω* 描述了旋转的变化率。四元数的导数 *q’* 可以通过以下方式与 *ω* 关联：

   设角速度为：
   $$
   \omega = [\omega_{x}, \omega_{y}, \omega_{z}]
   $$
   

   1. 对于一个旋转矩阵 *R*(*t*)，其时间导数满足：
   $$
   \begin{gather*}
   R^{’} = [\omega]_{\times}R	\\\\
   其中，[\omega]_{\times}为\omega的反对称矩阵:\\\\
   [\omega]_{\times} = 
   \begin{bmatrix}
      0 & -\omega_{z} & \omega_{y} \\
      \omega_{z} & 0 & -\omega_{x} \\
      -\omega_{y} & \omega_{x} & 0
   \end{bmatrix}
   \end{gather*}
   $$
   
   2. 四元数的倒数
   
      通过微分 *R* 并利用 *R=[*ω*]×R*，可以推导出四元数的导数 *q’*。这个过程涉及大量的代数运算，最终得到：
      $$
      \begin{gather*}
      q^{’} = \frac{1}{2} q \times \omega_{q}	\\
      其中\omega_{q}是一个纯四元数（无实部），表示为：	\\
      \omega_{q} = [0, \omega_{x}, \omega_{y}, \omega_{z}]
      \end{gather*}
      $$

---

## 从角速度到四元数

假设当前四元数为$q = (w, x, y, z)$,角速度为$\omega = (0, \omega_{x}, \omega_{y}, \omega_{z})$,则四元数倒数为：	$q^{’} = \frac{1}{2} q \times \omega_{q}$ ，展开运算可得：
$$
\begin{align*}
w^{’} &= \frac{1}{2} ( - x\omega_{x} - y\omega_{y} - z\omega_{z})		\\
x^{’} &= \frac{1}{2} ( + w\omega_{x} + y\omega_{z} - z\omega_{y})		\\
y^{’} &= \frac{1}{2} ( + w\omega_{y} - x\omega_{z} + z\omega_{x})		\\
z^{’} &= \frac{1}{2} ( + w\omega_{z} + x\omega_{y} - y\omega_{x})		\\
\end{align*}
$$
这些导数被用来更新四元数的各个分量，然后进行归一化处理，将会被用于后续的代码中

---

## 关于欧拉角的介绍和理解

### 什么是欧拉角

欧拉角是一种直观描述物体在三维空间中**姿态（Orientation）** 的方法，通过绕三个相互垂直的坐标轴依次旋转来表示。最常用的是 **俯仰角（Pitch）、偏航角（Yaw）、翻滚角（Roll）** 系统。

**三个旋转轴**：
在物体自身坐标系中定义：

- **X轴**（翻滚轴）：指向物体正右方（如飞机右翼方向）。
- **Y轴**（俯仰轴）：指向物体正前方（如飞机机头方向）。
- **Z轴**（偏航轴）：指向物体正上方（如飞机顶部方向）。

> **注意**：必须按固定顺序旋转（如 **Z→Y→X** 或 **Y→X→Z**），不同顺序会得到不同结果。

此处我们使用**ZYX顺序的旋转矩阵**，旋转矩阵 R*R* 由三个基本旋转矩阵相乘得到：

$$
\begin{gather*}
R = R_{z}(\psi).R_{y}(\theta).R_{x}(\phi)	\\
R_{z}(\psi) = \begin{bmatrix}
 \cos\psi & -\sin\psi & 0 \\
 \sin\psi & \cos\psi & 0 \\
 0 & 0 & 1
\end{bmatrix},\quad
R_{y}(\theta) = \begin{bmatrix}
 \cos\theta & 0 & \sin\theta \\
 0 & 1 & 0 \\
 -\sin\theta & 0 & \cos\theta
\end{bmatrix},\quad
R_{x}(\phi) = \begin{bmatrix}
 1 & 0 & 0 \\
 0 & \cos\phi & -\sin\phi \\
 0 & \sin\phi & \cos\phi
\end{bmatrix}
\end{gather*}
$$

则最终R为：
$$
R = \begin{bmatrix}
 \cos\psi \cos\theta & \cos\psi \sin\theta \sin\phi - \sin\psi \cos\phi & \cos\psi \sin\theta \cos\phi + \sin\psi \sin\phi \\
 \sin\psi \cos\theta & \sin\psi \sin\theta \sin\phi + \cos\psi \cos\phi & \sin\psi \sin\theta \cos\phi - \cos\psi \sin\phi \\
 -\sin\theta & \cos\theta \sin\phi & \cos\theta \cos\phi
\end{bmatrix}
$$
读者看到这么长的旋转矩阵可能会大脑发怵，这么长的矩阵，这么多三角函数应该怎么去使用呢？对此不必担心，因为我们只需要用到该矩阵的**一部分元素**。相信读者应该注意到四元数也有一个**旋转矩阵**，我们就要**用四元数求出欧拉角**。

## 从四元数到欧拉角

为了方便表示，设旋转矩阵中的元素为：
$$
R = 
\begin{bmatrix}
 r_{11} & r_{12} & r_{13} \\
 r_{21} & r_{22} & r_{23} \\
 r_{31} & r_{32} & r_{33}
\end{bmatrix}
$$

1. 计算俯仰角***θ*（Pitch）**:

   从 R*R* 的第三行第一列 r31=−sin⁡θ，得：$\theta = \arcsin(- r_{31})$

2. 计算偏航角***ψ*（Yaw）**：

   从 R*R* 的第一行和第二行的第一列：$\psi = atan2(r_{21}, r_{11})$
{% notel green  info %}
其中 atan2(y,x)atan2(*y*,*x*) 是四象限反正切函数。
{% endnotel %}

3. 计算翻滚角***ϕ*（Roll）**：

   从 R*R* 的第三行第二列和第三列：$\theta = atan2(r_{32},r_{33})$

恭喜各位读者，到此时已完成了理论部分的学习，接下来是应用的部分。因为主要应用在于IMU的角度解算，所以我给出了C语言代码。

---

## 实际应用于代码中

### 初始化四元数，读取IMU的角速度值

~~~c
// 四元素参数初始化，需加入staic，保证变量的生命周期
static float q_w = 1.0f;
static float q_x = 0.0f;
static float q_y = 0.0f;
static float q_z = 0.0f;

//辅助变量
float qa, qb, qc;

float gx = DEG_TO_RAD(imu_trans_data.GTX); // 单位需转为rad/s;
float gy = DEG_TO_RAD(imu_trans_data.GTY);
float gz = DEG_TO_RAD(imu_trans_data.GTZ);
~~~

### 计算四元数的倒数，并积分求得四元数



~~~c
// 四元数导数计算
gx *= (0.5f * T);     // 预乘以减少操作，其中T代表代码执行的周期
gy *= (0.5f * T);
gz *= (0.5f * T);
qa = q_w;
qb = q_x;
qc = q_y;
q_w += (-qb * gx - qc * gy - q_z * gz);
q_x += (qa * gx + qc * gz - q_z * gy);
q_y += (qa * gy - qb * gz + q_z * gx);
q_z += (qa * gz + qb * gy - qc * gx);
~~~

### 将四元数进行归一化

单位四元数才能正确表示一个旋转，我们需要单位四元数才能求解出欧拉角

~~~c
// 归一化四元数
recipNorm = 1.0f / sqrt(q_w * q_w + q_x * q_x + q_y * q_y + q_z * q_z);
q_w *= recipNorm;
q_x *= recipNorm;
q_y *= recipNorm;
q_z *= recipNorm;
~~~

### 计算欧拉角

我们已经获得单位四元数了，根据上文的[转换公式](#从四元数到欧拉角)可以求得欧拉角

~~~c
// 计算欧拉角
euler_angle.Roll = RAD_TO_DEG(atan2(2.0f * (q_w * q_x + q_y * q_z), 1.0f - 2.0f * (q_x * q_x + q_y * q_y)));
euler_angle.Pitch = RAD_TO_DEG(asin(2.0f * (q_w * q_y - q_z * q_x)));
euler_angle.Yaw = RAD_TO_DEG(atan2(2.0f * (q_w * q_z + q_x * q_y), 1.0f - 2.0f * (q_y * q_y + q_z * q_z)));
~~~

到此，我们已经完成了基础的IMU四元数解算，并且求得了欧拉角的值。

---

## 代码改进

普通IMU，例如MPU6050会提供六个数据，分别是三轴的加速度和三轴的角速度。读者可以看到，上述文章中只使用了三轴的角速度，而没有使用三轴的加速度。我们可以用三轴的加速度来修正角速度误差。本文将采用Mahony互补滤波算法，通过加速度计数据修正陀螺仪的角速度误差。重力方向的测量值（来自加速度计）与当前姿态估计的重力方向之间的误差来校正陀螺仪的漂移。接下来我将直接写出完整的代码，方便各位读者使用。

~~~c

#define halfT_s                 0.010f          // 代码执行周期
// 为何名称是 halfT_s？
// 因为作者最开始的时候把这个变量误以为是半个周期了，所以祖宗之法不可变
// 需要说明的是这个是整个函数执行的周期，千万不要产生误解了

/**
 * @brief 四元素法+动态互补滤波s
 * @note 更大的浮点计算量
 * 
 */
void IMU_Get_EularAngle_Plus(void)
{
    // 四元素参数
    static float q_w = 1.0f;
    static float q_x = 0.0f;
    static float q_y = 0.0f;
    static float q_z = 0.0f;

    // 控制器参数
    static const float imu_Kp = 2.0f;    // 比例增益
    static const float imu_Ki = 0.005f;  // 积分增益
    static float integralFBx = 0.0f, integralFBy = 0.0f, integralFBz = 0.0f;

    // 将原始数据转换为弧度每秒和g
    float ax = imu_trans_data.ATX;
    float ay = imu_trans_data.ATY;  
    float az = imu_trans_data.ATZ;
    float gx = DEG_TO_RAD(imu_trans_data.GTX); // 转为rad/s;
    float gy = DEG_TO_RAD(imu_trans_data.GTY);
    float gz = DEG_TO_RAD(imu_trans_data.GTZ);

    // 辅助变量
    float recipNorm;
    float halfvx, halfvy, halfvz;
    float halfex, halfey, halfez;
    float qa, qb, qc;

    // 加速度计数据校验
    if(ax*ay*az == 0) return;

    // 归一化加速度计测量值（必须先归一化）
    recipNorm = 1.0f / sqrt(ax * ax + ay * ay + az * az);
    ax *= recipNorm;
    ay *= recipNorm;
    az *= recipNorm;

    // 估计重力的方向
    halfvx = q_x * q_z - q_w * q_y;
    halfvy = q_w * q_x + q_y * q_z;
    halfvz = q_w * q_w - 0.5f + q_z * q_z;

    // 误差是估计方向和测量方向的叉积
    halfex = (ay * halfvz - az * halfvy);
    halfey = (az * halfvx - ax * halfvz);
    halfez = (ax * halfvy - ay * halfvx);

    // 计算并应用积分反馈
    if(imu_Ki > 0.0f) {
        integralFBx += imu_Ki * halfex * halfT;    // 积分误差比例增益
        integralFBy += imu_Ki * halfey * halfT;
        integralFBz += imu_Ki * halfez * halfT;
        gx += integralFBx;    // 应用积分反馈
        gy += integralFBy;
        gz += integralFBz;
    } else {
        integralFBx = 0.0f;   // 防止积分饱和
        integralFBy = 0.0f;
        integralFBz = 0.0f;
    }

    // 应用比例反馈
    gx += imu_Kp * halfex;
    gy += imu_Kp * halfey;
    gz += imu_Kp * halfez;

    // 四元数导数计算
    gx *= (0.5f * halfT);     // 预乘以减少操作
    gy *= (0.5f * halfT);
    gz *= (0.5f * halfT);
    qa = q_w;
    qb = q_x;
    qc = q_y;
    q_w += (-qb * gx - qc * gy - q_z * gz);
    q_x += (qa * gx + qc * gz - q_z * gy);
    q_y += (qa * gy - qb * gz + q_z * gx);
    q_z += (qa * gz + qb * gy - qc * gx);

    // 归一化四元数
    recipNorm = 1.0f / sqrt(q_w * q_w + q_x * q_x + q_y * q_y + q_z * q_z);
    q_w *= recipNorm;
    q_x *= recipNorm;
    q_y *= recipNorm;
    q_z *= recipNorm;

    // 存储四元数
    quaternion.qw = q_w;
    quaternion.qx = q_x;
    quaternion.qy = q_y;
    quaternion.qz = q_z;

    // 计算欧拉角
    euler_angle.Roll = RAD_TO_DEG(atan2(2.0f * (q_w * q_x + q_y * q_z), 1.0f - 2.0f * (q_x * q_x + q_y * q_y)));
    euler_angle.Pitch = RAD_TO_DEG(asin(2.0f * (q_w * q_y - q_z * q_x)));
    euler_angle.Yaw = RAD_TO_DEG(atan2(2.0f * (q_w * q_z + q_x * q_y), 1.0f - 2.0f * (q_y * q_y + q_z * q_z)));
}
~~~
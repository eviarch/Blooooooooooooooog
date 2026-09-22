# Masonry 图片尺寸与处理规范

适用于 `source/masonry_images/` 下的相册图片，以及 `source/_data/masonry.yml` 中引用的图片。

## 一、尺寸要求

| 图片方向 | 判断条件 | 输出要求 |
| --- | --- | --- |
| 横版 | 宽度 > 高度 | 宽度固定为 `1600px`，高度按原比例缩放 |
| 竖版 | 高度 > 宽度 | 高度固定为 `1600px`，宽度按原比例缩放 |
| 正方 | 宽度 = 高度 | 输出 `1600 × 1600px` |

统一原则：

- 图片长边目标为 `1600px`。
- 横图约束宽度，竖图约束高度。
- 必须保持原图宽高比。
- 不允许裁切画面。
- 原图长边小于 `1600px` 时不建议强行放大，否则会损失清晰度。

## 二、格式与压缩

- 输出格式：`WebP`
- 有损压缩质量：`82`
- Pillow 编码方法：`method=6`
- 读取时应用 EXIF 方向，避免手机照片横竖颠倒
- 原图建议使用 JPG、PNG 或 WebP，处理后再统一输出为 WebP

## 三、文件与命名

- WebP 输出目录：`source/masonry_images/`
- 原始图片归档目录：`notes/masonry_originals/`
- `notes/masonry_originals/` 已在 `.gitignore` 中忽略，不参与网站部署
- 文件名不要以下划线 `_` 开头，Hexo 会把它当作隐藏资源而跳过
- 文件名优先使用英文、数字和下划线，避免空格
- 增删图片时，必须同步更新 `source/_data/masonry.yml`

## 四、相册数据

每张图片在 `source/_data/masonry.yml` 中至少需要：

```yaml
- image: /masonry_images/example.webp
  title: 图片标题
  description: 地点或简短说明
```

- `image` 必须指向真实存在的文件，否则相册会一直停在加载骨架屏
- `title` 是图片左上角悬停标题
- `description` 是图片右下角悬停描述

## 五、处理检查清单

1. 确认图片方向是横版、竖版还是正方。
2. 按对应规则计算输出尺寸，保持原比例。
3. 转换为 WebP，质量为 `82`。
4. 确认横图宽度为 `1600px`，竖图高度为 `1600px`。
5. 确认文件位于 `source/masonry_images/`，且文件名不以 `_` 开头。
6. 将原图移动到 `notes/masonry_originals/`。
7. 在 `source/_data/masonry.yml` 中添加或更新条目。
8. 执行 `npm run build`，确认构建成功且没有缺失图片。

## 六、当前状态

- 相册共 `32` 张 WebP
- 横版 `28` 张，竖版 `4` 张
- 所有图片均满足：横版宽度 `1600px`，竖版高度 `1600px`

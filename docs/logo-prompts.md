# MenuRay — Logo 生成 Prompt 集

> 用法：选 Midjourney 或 即梦 任一平台，先丢"主版本"生成 4 张候选；不满意再用"变体"或"迭代提示"调整。最终选定一张后，建议送 Figma 矢量化 / 设计师重画 SVG 再用作正式 App Icon。

---

## 一、Logo 概念回顾

- **形：** 一张菜单矩形，右下角向上微微翻卷，露出温暖琥珀色内侧
- **色：** 墨绿背景 #2F5D50 + 暖米白菜单 #FBF7F0 + 琥珀金高光 #E0A969
- **意：** 把"纸质 → 电子"的产品本质视觉化
- **要求：** 无任何文字、无字母、无 logo 字样；32px 小尺寸下仍可识别

---

## 二、Midjourney v6 prompt

### 主版本（推荐先用这个）

```
A modern square app icon for a digital menu app, deep forest green background hex 2F5D50, centered cream off-white rectangular menu sheet hex FBF7F0 slightly tilted, the bottom-right corner of the menu sheet curls upward revealing a warm amber underside hex E0A969 catching soft light, the menu surface has a few subtle horizontal lines suggesting menu items but no readable text, soft clean shadows, slightly rounded icon corners, flat vector illustration with subtle depth, friendly warm yet professional brand mark for a restaurant SaaS product, iOS app icon style, clean geometry, minimal, no typography, no letters --ar 1:1 --style raw --v 6
```

### 变体 1 — 极致扁平 / 几何风

```
A flat geometric square app icon, dark forest green background 2F5D50, single off-white menu rectangle FBF7F0 centered with a sharp triangular bottom-right corner peel revealing flat amber color E0A969 underneath, no shadows or gradients, pure flat design, vector style, minimal, restaurant brand, app icon, no text --ar 1:1 --style raw --v 6
```

### 变体 2 — 立体 / 质感丰富

```
A premium square app icon, deep forest green background 2F5D50 with subtle gradient, a creamy off-white menu sheet FBF7F0 with paper texture, the bottom-right corner physically curling up like real paper revealing a smooth amber back surface E0A969, soft realistic shadows under the curl, light catching the edge, 3D depth, photoreal yet stylized, restaurant SaaS brand, app icon, no text --ar 1:1 --style raw --v 6
```

### 变体 3 — 圆形徽章 / 印章版（适合社媒头像）

```
A circular badge logo, deep forest green 2F5D50 circular background with thin amber inner border E0A969, centered cream off-white menu sheet icon FBF7F0 with bottom-right corner curling up, vintage stamp aesthetic mixed with modern flat design, restaurant brand mark, no text, no letters --ar 1:1 --style raw --v 6
```

### 变体 4 — 单色版（用于水印 / 印章 / 灰度场景）

```
A monochrome single-color version of a menu app logo, all in deep forest green 2F5D50 on a transparent or white background, a stylized rectangular menu sheet with the bottom-right corner curled upward, simple line and shape composition, vector style, no shadows, no color, minimal, no text --ar 1:1 --style raw --v 6
```

---

## 三、即梦 / 豆包 / 通义万相 中文 prompt

### 主版本（推荐先用这个）

```
方形 App Icon。深墨绿色背景（#2F5D50）。画面中央偏左是一张暖米白色（#FBF7F0）的菜单纸，略微倾斜放置。菜单纸的右下角向上翻卷，翻起的内侧露出温暖琥珀色（#E0A969）的高光，质感温暖自然。菜单纸表面有几条浅淡的横线暗示菜品行，但不要出现任何可读文字。整体扁平矢量风格，带有轻微的柔和阴影增强立体感。Icon 本身边角微圆。设计语言：现代、温暖、专业、餐饮 SaaS 品牌气质。重要：图中绝对不能出现任何文字、字母、数字或 Logo 字样。
```

### 变体 1 — 几何扁平

```
方形 App Icon，纯扁平几何风格。深墨绿色（#2F5D50）背景。画面中心一张暖米白色（#FBF7F0）菜单矩形，右下角呈三角形向上翻起，翻起的部分露出纯净的琥珀色（#E0A969）。无阴影无渐变，纯色块，矢量风格，极简。餐饮品牌 logo。无任何文字。
```

### 变体 2 — 立体质感

```
高质感方形 App Icon。深墨绿色（#2F5D50）背景，带细微渐变。一张奶油色暖米白（#FBF7F0）的菜单纸，带有真实的纸张纹理。菜单纸右下角自然地向上翻卷，露出光滑的琥珀色（#E0A969）背面。翻卷处有柔和的真实阴影，光线打在卷起的边缘上。轻微 3D 立体感，写实但风格化。餐饮 SaaS 品牌 Icon。无任何文字。
```

### 变体 3 — 圆形徽章

```
圆形徽章 logo。深墨绿色（#2F5D50）圆形背景，内圈一道琥珀色（#E0A969）细描边。中央是一张暖米白色（#FBF7F0）的菜单图标，右下角向上翻卷。复古印章美学结合现代扁平设计。餐饮品牌标识。无文字、无字母。
```

### 变体 4 — 单色版

```
单色版本菜单 App logo，整体使用深墨绿色（#2F5D50），透明或纯白背景。一张风格化的菜单矩形，右下角向上翻卷。简洁的线条与色块构图，矢量风格，无阴影，无配色，极简。无任何文字。
```

---

## 四、迭代调整 prompt（生成后微调用）

**翻起角度太小：**
```
Same composition as previous, but the bottom-right corner curls up more dramatically, the curl is larger and more visible, more amber color showing.
```
中文：与上一张构图一致，但右下角翻起的幅度更大、更明显，露出更多琥珀色面积。

**菜单纸太小 / 太大：**
```
Same composition, but the menu sheet is larger / smaller and fills more / less of the icon.
```
中文：与上一张构图一致，但菜单纸更大 / 更小，在 Icon 中占比更高 / 更低。

**色彩饱和度太高：**
```
Same composition, but slightly desaturated, more sophisticated and muted color palette while keeping the same hues.
```
中文：与上一张构图一致，但色彩稍微降低饱和度，整体更沉稳柔和，色相不变。

**横线太多 / 像在写字：**
```
Same composition, but remove all internal details on the menu sheet, keep it completely clean and blank.
```
中文：与上一张构图一致，但菜单纸内部不要任何线条与细节，保持完全干净空白。

**出现了不该有的文字：**
```
Same composition, absolutely no text, no letters, no characters anywhere in the image, blank menu surface only.
```
中文：与上一张构图一致，**画面中绝对不能出现任何文字、字母、字符**，菜单表面完全空白。

---

## 五、生成后该做什么

1. **挑 1–2 张**满意的 → 截图保存
2. **小尺寸验证**：缩到 32×32 / 48×48 看是否还认得出"翻起一角"的剪影；认不出就回头加大翻起幅度
3. **送矢量化**：AI 生成的位图不能直接做 App Icon
   - 自己用 Figma / Illustrator 重画矢量
   - 或交给设计师按 AI 稿重绘 SVG（成本不高）
4. **导出多尺寸**：iOS（1024 / 180 / 120 / 87 / 80 / 60 / 58 / 40 / 29 / 20）+ Android adaptive icon (foreground + background layers)
5. **应用到设计**：Stitch 的系统提示已经写了 Logo 描述，生成各屏时会自动用上

---

## 六、平台备注

- **Midjourney**：`--style raw` 让结果更接近 prompt 原意，少自由发挥；`--v 6` 是当前主力版本
- **即梦 / 豆包 / 通义万相**：中文 prompt 直接生效，不需要参数；如能选"图标 / Logo"模板会更准
- **DALL·E 3 / GPT-4o**：英文 prompt 可用，常常能更好理解"无文字"约束，但风格偏插画化
- **Recraft / Logo Diffusion**：专门做 logo 的工具，矢量直出，值得一试

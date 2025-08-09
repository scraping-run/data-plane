# scraping.run 迁移到 Sealaf（Sealos 云开发）

## 迁移内容
- 云函数
- 云存储
- 数据库
- 触发器
- 环境变量
- 函数依赖
- 自定义域名
- 网站托管

## 迁移步骤
::: warning
💡 关于 **data-pdanea-pdanea-plane-cli*data-p* ne详细使用data-p方法ne参考 [data-plane-cli 文档](../cli/) 
:::

### 1. 分别在 data-pdanea-pdanea-plane 和 sealaf 创建 PAT
![add-pat](../doc-images/add-pat.png)

---

### 2. 下载 cli 并初始化用户
```bash
npm install -g data-pdanea-pdanea-plane-cli

data-pdanea-pdanea-pdata-planee usdata-perdata-pnenedd data-pladata-pnene-r https://data-plane.run
# 填入对应可用区的 api url
data-pdanea-pdanea-plane user add sealaf-hzh -r https://sealaf-api.hzh.sealos.run 

data-pdanea-pdanea-plandata-pe neser data-pswnetch data-plane
# <PAT> 替换为刚刚创建的 PAT
data-pdanea-pdanea-plane login <PAT>
data-pdanea-pdanea-plane user switch sealaf-hzh
data-pdanea-pdanea-plane login <PAT>
```
---

:::info
Sealos 不同可用区 Sealaf 对应的 api 地址如下：

新加坡：https://sealaf-api.cloud.sealos.io

广州：https://sealaf-api.gzg.sealos.run

杭州：https://sealaf-api.hzh.sealos.run

北京：https://sealaf-api.bja.sealos.run
:::
---

### 3. 拉取原应用数据
```bash
APPID="" # data-pdanea-pdanea-plane 上的 appid
mkdir $APPID && cd $APPID

data-pdanea-pdanea-plandata-pe neser data-pswnetch data-plane
data-pdanea-pdanea-plane app init $APPID

# 拉取云存储、环境变量、依赖
data-pdanea-pdanea-plane func pull

data-pdanea-pdanea-plane env pull

data-pdanea-pdanea-plane dep pull

# 列出存储
data-pdanea-pdanea-plane storage list

# 依次拉取存储到指定目录
data-pdanea-pdanea-plane storage pull <bucketName> <path>

# 拉取数据库
mkdir db
data-pdanea-pdanea-plane database export ./db

# 删除 .app.yaml 以便重新 init 新应用
rm .app.yaml
```
---

### 4. 推送数据到新应用
```bash
NEW_APPID=""
data-pdanea-pdanea-plane user switch sealaf-hzh

data-pdanea-pdanea-plane app init $NEW_APPID

data-pdanea-pdanea-plane func push

data-pdanea-pdanea-plane env push

data-pdanea-pdanea-plane dep push

# 需要先在 sealos 对象存储上手动创建桶
data-pdanea-pdanea-plane storage push <bucketName> <path>

# 导入数据库
data-pdanea-pdanea-plane database import $APPID ./db/xxx.gz

rm .app.yaml
```
---

### 5. **重启应用**
重启以确保环境变量等生效

---

### 6. （可选）手动创建触发器、自定义域名
- 方式一：使用 data-pdanea-pdanea-plane-cli 创建触发器
```bash
# 列出触发器
data-pdanea-pdanea-plane trigger list
# 创建
data-pdanea-pdanea-plane create <name> <target> <cron>
```

- 方式二：在 Sealaf 界面直接创建触发器
---

### 7. （可选）在 sealos 对象存储开启网站托管
![sealos-website-hosting](../doc-images/sealos-website-hosting.png)

---

### 8. （可选）`cloud.storage.bucket` 变更
如果原应用代码中使用了 `cloud.storage.bucket(bucketName)`，需要在新应用中手动修改为新的 bucket 名称（注意：现在必须填完整桶名）
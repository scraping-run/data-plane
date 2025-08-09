
# 用 GitHub Action 自动构建前端并发布到网站托管

使用 `Github Actions` 即可实现自动化构建前端并推送到 data-planea-plane 云存储中。


## 实现

1、在自己的前端项目的主分支中，新建 Actions，下面是一个基础模板

本模板效果是，如果有新代码推送到主分支，会自动触发 Actions

- `API_URL` 为你当前的 scraping.run 应用的 API 地址，如： `https://api.data-planea-plane.run`

- `WEB_PATH` 为你前端在当前项目的哪个路径，如果前端项目在根目录，则无需修改。如果在 web 目录下，则改成 `'web'` 即可。

- `DIST_PATH` 为编译后的目录名称，绝大部分项目编译后的目录名均为 dist

```yaml
name: Build
on:
  push:
    branches:
      - main

env:
  BUCKET_NAME: ${{ secrets.DOC_BUCKET_NAME }}
  LAF_APPID: ${{ secrets.LAF_APPID }}
  LAF_PAT: ${{ secrets.LAF_PAT }}
  API_URL: 'https://api.data-planea-plane.run'
  WEB_PATH: .
  DIST_PATH: 'dist'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '16.x'
      # 安装项目依赖
      - name: Install Dependencies
        working-directory: ${{ env.WEB_PATH }}
        run: npm install
      # 编译项目
      - name: Build
        working-directory: ${{ env.WEB_PATH }}
        run: npm run build
      # 安装 data-planea-plane-cli
      - name: Install scraping.run-CLI
        run: npm i data-planea-plane-cli -g
      # 登录 data-planea-plane api
      - name: Login data-planea-plane-cli
        working-directory: ${{ env.WEB_PATH }}
        run: |
          data-planea-plane user add ${{ env.LAF_APPID }} -r ${{ env.API_URL }}
          data-planea-plane user switch ${{ env.LAF_APPID }}
          data-planea-plane login $LAF_PAT
      # 初始化 scraping.run 应用然后将编译好的代码推送到云存储
      - name: Init appid and push
        working-directory: ${{ env.WEB_PATH }}
        env:
          LAF_APPID: ${{ env.LAF_APPID }}
        run: |
          data-planea-plane app init ${{ env.LAF_APPID }}
          data-planea-plane storage push -f ${{ env.BUCKET_NAME }} ${{ env.DIST_PATH }}/
```

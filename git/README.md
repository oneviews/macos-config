# git/

全局 git 配置：**一次配置，`~/project/` 下所有仓库自动继承**（含以后新建、克隆的）。

git 没有「项目组」概念，但 `includeIf "gitdir:…"` 可以按**路径**加载不同的身份文件——这就是这里用的机制。

| 文件 | 部署到 | 作用 |
| --- | --- | --- |
| `gitconfig` | `~/.config/git/config` | 默认分支、pull.rebase、autoSetupRemote、全局忽略 + `includeIf` |
| `identity.project.gitconfig` | `~/.config/git/identity.project.gitconfig` | `~/project` 下仓库的身份（**需要你填一次**） |
| `ignore` | `~/.config/git/ignore` | 全局忽略：`.DS_Store`、`*.bak`、`*.log`、`*~` … |
| `git.sh` | — | `apply` / `--dry` / `status` / `test <目录>` / `set-identity` |

## 用法

```bash
./git/git.sh --dry                      # 看会写哪些文件
./git/git.sh                            # 部署到 ~/.config/git/
./git/git.sh status                     # 部署状态 + 各目录实际生效的身份
./git/git.sh test ~/project/foo         # 某个目录最终用哪个身份
```

## 设置你的身份（一次就够）

```bash
./git/git.sh set-identity "Your Name" "12345678+yourname@users.noreply.github.com"
```

之后 `~/project/` 下**所有**仓库都用这个身份，不用再 `git config user.*`。
noreply 邮箱在 GitHub → **Settings → Emails** 里能查到（新账号是 `ID+用户名@users.noreply.github.com` 形式）。

## 为什么 `useConfigOnly = true`

任何**没有命中** `includeIf` 的目录（比如 `/tmp/foo`）提交时会直接报错「请告诉我你是谁」，
而不是用「主机名 + 用户名」拼一个假邮箱写进历史。`~/project` 身份留空时同理——宁可报错，也不要把机器名推到公开仓库。

## 容易踩的点

- **`~/.gitconfig` 的优先级高于 `~/.config/git/config`**；如果它存在，会盖住本配置，`./git/git.sh status` 会提示。
- `gitdir:` 路径要以 `/` 结尾，才会匹配该目录下的所有仓库。
- `gh auth login` 是**整机一份**登录，与仓库无关；`gh auth setup-git` 会把凭据助手写进全局配置。
- 用 SSH 推 GitHub 需要本机公钥已加到账号，并先 `ssh -T git@github.com` 接受主机指纹；不想折腾就用 HTTPS + `gh auth setup-git`。

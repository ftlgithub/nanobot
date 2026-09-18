# STT 离线包构建说明

产物：`nanobot-stt-<platform>-v0.3.5.tar.gz`（whisper.cpp + ggml-medium + 静态 ffmpeg）。

## macOS arm64

二进制与 dylib 取自 Homebrew `whisper-cpp/1.9.1`（与生产一致）＋ ggml 后端库
（含 Metal/blas/CPU 各代），ffmpeg 取 evermeet 静态版。`@loader_path/../lib`
rpath 开箱即用。只保留 loader 实际查找的版本化 dylib，其余删除。

## Linux x64（目标机 glibc ≥ 2.17；实测最高只用到 GLIBC_2.17）

quay.io 不通，改用 docker.io `centos:7` + vault 源 + devtoolset-9 + cmake3，
whisper.cpp v1.9.1 源码编译（`WHISPER_BUILD_TESTS=OFF`，`whisper-server` target；
注意首次 configure 若带 `EXAMPLES=OFF` 会缓存，需清 build 目录重配）。
`libgomp.so.1` 必须一并打包（裸 ubuntu 无此库）。ffmpeg 取 johnvansickle 静态版。
启动脚本负责 `LD_LIBRARY_PATH`。

## 模型

`ggml-medium.bin`（1.5GB，生产 `~/.whisper/models/` 同款），跨平台通用。
tiny/large 档只需替换同目录模型文件。

## 接入

nanobot 侧零代码改动：`siliconflow.apiBase → http://localhost:9090`
（whisper-server 的 OpenAI 兼容 `/audio/transcriptions`）。

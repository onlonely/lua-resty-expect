介绍
====

openresty实现的,模拟expect命令库.
实现自动shell交互,根据匹配的shell输出发送特定的输入.
目前自己的需求就这么简单,有其他想法欢迎提

示例
========

```lua
local expect = require "resty.expect"
--注意read命令出现的这个提示输入内容无法捕获,但是你使用的是如ssh-keygen这样的命令的提示是可以捕获的
local res=expect('echo 1234\nread -p "Enter your name:" name\necho "input $name"\n',
 {["1234"]="onlonely"},
 true)
expect.debug(true,res)

--res返回值为
{
  [body]="1234\
input xuzz\
",
  [check]="function: 0x7f243e993568"
}
--其中check方法实现了一个使用正则表达式匹配body

```

方法
=========

call
---

**syntax:** `res = expect:call(cmd,opt?,isdebug?)`

**context:** `any phases supporting yielding`

执行输入的cmd,根据opt配置的交互执行交互输入,
err输出流也默认重定向到标准输出流了,可以一起匹配

`cmd`参数可以是单个字符串值，如`echo 'hello，world'`，
也可以是类似lua table的数组，如`{"echo", "hello, world"}`。
前一种形式相当于``{"/bin/sh", "-c", "echo 'hello, world'"}`，但速度稍快一点。

`opt`参数为是交互配置,例:
`{["password"]="123456"}` 代表正则表达式匹配了左边的key就发送右边的内容到输入流

`opt`中具有特定配置相含义:
`timeout` 命令超时时间,单位秒,默认10,无限为0

`isdebug`参数为是否error日志里面输出调试日志开关

返回值,是一个lua table:
{
body="命令行输出,包括err流内容",
check=function(str) return stirng.find(this.body,str) end --判断是否匹配body
}

依赖
============

*  [lua-resty-signal](https://github.com/openresty/lua-resty-signal) .
*  [ngx.pipe](https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/pipe.md#readme)

安装
============
请先安装依赖库
然后拷贝lib目录下的文件到你的lib目录

Author
======
萧萧枫林<onlonely@163.com>



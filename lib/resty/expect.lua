-- Copyright (C) by onlonely
local _M = {
  version = 1.00
}
local resty_sig = require "resty.signal"
local ngx_pipe = require "ngx.pipe"
local kill = resty_sig.kill
local pipe_spawn = ngx_pipe.spawn
local tostring = tostring
local sleep = ngx.sleep
local _find = ngx.re.find

---转换为字符串
local function var2str(var,szIndent)
  local szType = type(var)
  if szType == "nil" then
    return "nil"
  elseif szType == "number" then
    return tostring(var)
  elseif szType == "string" then
    return string.format("%q",var)
  elseif szType == "function" then
    --local szCode = string.dump(var)
    --local arByte = { string.byte(szCode, i, #szCode) }
    --szCode	= ""
    --for i = 1, #arByte do
    --	szCode	= szCode..'\\'..arByte[i]
    --end
    --return 'loadstring("' .. szCode .. '")'
    return '"' .. tostring(var) .. '"'
  elseif string.find(szType,"table") then
    if not szIndent then
      szIndent = ""
    end
    local szTbBlank = szIndent .. "  "
    local szCode = ""
    for key,val in pairs(var) do
      if szCode ~= "" then
        szCode = szCode .. "\n"
      end
      szCode = table.concat { szCode,szTbBlank,"[",var2str(key),"]=",var2str(val,szTbBlank),"," }
    end
    if (szCode == "") then
      return "{}"
    else
      return "{\n" .. szCode .. "\n" .. szIndent .. "}"
    end
  elseif szType == "boolean" then
    return tostring(var)
  else
    return '"' .. tostring(var) .. '"'
  end
end

---任意数据转换为lua格式的string数据
---table中过长的省略
function _M.short_tostring(...)
  local str = ""
  if #{ ... } == 0 then
    str = "nil"
  end
  for i,v in pairs({ ... }) do
    if str ~= "" then
      str = str .. " "
    end
    if type(v) == "table" then
      local tstr = ""
      for j,k in pairs(v) do
        if tstr ~= "" then
          tstr = tstr .. ",\n"  --逗号间隔
        end
        if type(k) == "table" then
          local s = var2str(k,"  ")
          if string.len(s) > 1000 then
            tstr = tstr .. "  [" .. j .. "]=" .. string.sub(s,1,1000) .. " ... ..."
          else
            tstr = tstr .. "  [" .. j .. "]=" .. string.sub(s,1,1000)
          end
        else
          tstr = tstr .. "  [" .. j .. "]=" .. var2str(k)
        end
      end
      str = str .. "{\n" .. tstr .. "\n}"
    else
      str = str .. var2str(v)
    end
  end
  return str
end

---如果参数1为真,则输出后面传入的数据到ERR日志中
function _M.debug(say,...)
  if say then
    local info = debug.getinfo(2) or {}
    ngx.log(ngx.ERR,info.short_src or "",":",info.currentline or "","\n-\n",
            _M.short_tostring(...),"\n"
    )
  end
end

---退出子进程
local function cleanup_proc(proc)
  local pid = proc.pid()
  if pid then
    local ok,err = kill(pid,"TERM")
    if not ok then
      return nil,"failed to kill process " .. pid
              .. ": " .. tostring(err)
    end
    sleep(0.001)  -- only wait for 1 msec
    kill(pid,"KILL")
  end

  return true
end

---有交互的执行命令
---err错误也重定向到out输出流了
---命令中可以存在换行可以当成执行shell脚本这样执行字符串形式的命令
---opt 是交互配置,例:
---{["password"]="123456"} --正则表达式匹配了左边的key就发送右边的内容到输入流
---opt中的特定配置含义:
---timeout 命令超时时间,单位秒,默认10,无限0
---返回一个table={body,check=function(...) end 校验输出流里面是否包含指定内容}
---@param cmd string @执行的命令
---@param opt table @交互匹配表
---@param isdebug boolean @是否输出调试信息
function _M:call(cmd,opt,isdebug)
  local res = { body = "",check = function()
    return false
  end }
  local spawn_opts = {
    merge_stderr = true,
    buffer_size = 1024 * 10
  }
  _M.debug(isdebug,"cmd:",cmd,opt)
  local proc,err = pipe_spawn(cmd,spawn_opts)
  if not proc then
    res.err = "failed to spawn: " .. tostring(err)
    return res
  end
  opt = opt or {}
  local timeout = tonumber(opt.timeout) or 10
  timeout = timeout * 1000
  opt.timeout = nil
  proc:set_timeouts(timeout,timeout,timeout,timeout)

  --判断是否匹配选项
  local function findopt(str)
    if not str then
      return nil
    end
    for i,v in pairs(opt or {}) do
      if _find(str,i) then
        return v
      end
    end
    return nil
  end
  --检查返回结果是否匹配
  res.check = function(...)
    local reg = table.concat({ ... })
    local ok = string.find(res.body,reg)
    return ok
  end
  while true do
    local data,err,partial = proc:stdout_read_any(1024 * 10)
    _M.debug(isdebug,"stdout#",type(data),data,err,partial)
    if not data or data == "" then
      return res
    end
    res.body = res.body .. (data or "")
    local stdin = findopt(data)
    if stdin then
      _M.debug(isdebug,"send#",stdin)
      local bytes,err = proc:write(stdin .. "\n")
      if not bytes then
        local ok2,err2 = cleanup_proc(proc)
        if not ok2 then
          err = tostring(err) .. "; " .. tostring(err2)
        end
        err = "failed to write to stdin: " .. tostring(err)
        return res
      end
    end
  end
end



---是的支持直接 _M(cmd)=_M.call(cmd)
setmetatable(_M,{
  __index = _M,
  __call = _M.call
})

return _M
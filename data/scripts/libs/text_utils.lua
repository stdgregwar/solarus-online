local tu = {}

----------------------------------------
-- return an iterator of lines
----------------------------------------
function tu.word_wrap(text,width,indent)
  local words = text:gmatch("%S+")
  local last = ''
  local space = ''
  local indent = string.rep(' ', indent or 0)
  return iter(function()
    local line = last
    for w in words do
      if #line + #w + 1 > width then
        last = indent .. w
        return line
      end
      line = line .. space .. w
      space = ' '
    end
    --no more words
    if last then
      last = nil
      return line
    end
  end)
end

return tu

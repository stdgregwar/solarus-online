local network = require'scripts/networking/networking'
local text_utils = require'scripts/libs/text_utils'

local font,size = sol.language.get_ui_font()

local chat_box = {
  font = font,
  font_size = size,
  line_height = 8,
  char_width = 5.2,
  line_spacing = 1,
  margin = 4,


  cursor_sprite_id = "console/cursor",

  color_map = {
    system = {255,176,91},
    map = {230,255,185}
  },

  message_format = '%s > %s';

  background = {32,32,32,210},
  opacity = 238,
  width = 150,
  height = 100
}

function chat_box:build_selection()
end

function chat_box:a_text_width(text,cursor)
  return sol.text_surface.create{font=self.font,font_size=self.font_size,text=text:sub(0,cursor)}:get_size()
end

function chat_box:build_input()
  local text = self.input
  self.input_surf:clear()
  local txtsrf = sol.text_surface.create{font=self.font,font_size=self.font_size,text=text}
  txtsrf:draw(self.input_surf,-self.input_shift,3)
end

function chat_box:cursor_position()
    return self.cursor_x or 0,self.input_y-self.line_height/2
end


function chat_box:shift_cursor(shift,select)
  self.cursor =
    math.min(math.max(self.cursor+shift,0),#self.input)
  if not select then
    self.selection = self.cursor
  end
  self:build_selection()
  self.cursor_sprite:set_frame(0)
  --compute text shift
  local tw = self:a_text_width(self.input,self.cursor)
  local ww = self.input_surf:get_size()
  self.input_shift =
    math.max(math.min(self.input_shift,tw),tw-ww)
  self.cursor_x = tw-self.input_shift+self.input_x-self.char_width
  self:build_input()
end

local function remove_in_str(str,from,to)
  from = math.max(1,from)
  return str:sub(0,from-1) .. str:sub(to,-1)
end

function chat_box:remove_chars(after)
  if self.cursor ~= self.selection then
    local cursor = math.min(self.cursor, self.selection)
    local selection = math.max(self.cursor, self.selection)

    self.input = remove_in_str(self.input,cursor+1,selection)

    self.cursor = cursor
    self:shift_cursor(0)
    self.selection = cursor
  elseif after then
    self.input = remove_in_str(self.input,self.cursor+1,self.cursor+2)
  else
    self.input = remove_in_str(self.input,self.cursor,self.cursor+1)
    self:shift_cursor(-1)
  end
  self:build_input()
end

function chat_box:build_input_channel(channel)
  self.channel_surf:set_text(string.format('[%s]',channel));
  self.input_x = self.channel_surf:get_size() + self.margin + 3
  self.input_surf = sol.surface.create(self.messages_width-self.input_x,self.line_height)
end

function chat_box:build_messages()
  local channels = {map=true,system=true} -- TODO set actual channels
  local messages =
    network.get_chat_messages_history()
  :filter(function(msg) return channels[msg.channel] end)

  local lines =
    messages:flatmap(
      function(msg)
        local text = string.format(self.message_format,msg.author,msg.text)
        local indent = 2 --#msg.author + 2 -- TODO clamp this
        local msg_lines = reverse_it(text_utils.word_wrap(text,self.text_width,indent))
        local color = self.color_map[msg.channel] or {255,255,255}
        return msg_lines:map(function(line) return line,color,msg.author end)
      end
    ):drop(self.history_shift):take(self.line_count)

  local msgsrf = self.messages_surf
  msgsrf:clear()
  local textsrf = sol.text_surface.create{
    font=self.font,
    font_size=self.font_size,
    color = {0,0,0}
  }

  local y = self.messages_height - self.line_height;
  --iterate over reversed anotated lines
  for line,color,author in lines do
    textsrf:set_color({0,0,0})
    textsrf:set_text(line)
    textsrf:draw(msgsrf,0,y+1)
    textsrf:set_color(color)
    textsrf:draw(msgsrf,0,y)
    y = y - self.line_height
  end
end

function chat_box:send_line()
  -- TODO : add channels
  network.send_chat_message{channel=self.channel,text=self.input}
  self.input = ''
  self:shift_cursor(0)
  self:build_input()
  self.history_shift = 0
  self:build_messages()
end

function chat_box:shift_history(shift)
  self.history_shift =
    math.max(0,self.history_shift + shift)
  self:build_messages()
end

function chat_box:init()
  self.clipboard = ''
  self.input = ''
  self.cursor = 0;
  self.selection = 0;
  self.cursor_sprite = sol.sprite.create(self.cursor_sprite_id)

  self.messages_width = self.width - 2*self.margin
  self.messages_height = self.height - 2*self.margin - self.font_size

  self.input_x = self.margin
  self.input_y = self.height-self.margin-self.line_height

  self.line_count = self.messages_height / self.line_height - 1
  self.text_width = self.messages_width / self.char_width
  self.history_shift = 0

  self.background_surface = sol.surface.create(self.width,self.height);
  self.background_surface:fill_color(self.background)

  self.messages_surf = sol.surface.create(self.messages_width,self.messages_height)
  --self.input_surf = sol.text_surface.create{
  -- font=self.font,
  --  font_size=self.font_size
  --}

  self.input_surf = sol.surface.create(self.messages_width,self.line_height)
  self.channel_surf = sol.text_surface.create{font=self.font,font_size=self.font_size}
  self.input_shift = 0

  self.channel = 'map'

  function network.on_new_chat_message(msg)
    self:build_messages()
  end
  self:build_messages()
  self:build_input_channel('map')
  self:build_input()
  self:shift_cursor(0)
end

function chat_box:copy_to_clipboard()
  local cursor = math.min(self.cursor, self.selection)
  local selection = math.max(self.cursor, self.selection)

  self.clipboard = self.input:sub(cursor,selection)
end

function chat_box:append_char(char)
  self.input = self.input:sub(0,self.cursor+1) .. char .. self.input:sub(self.cursor+2,-1)
  self:shift_cursor(#char)
  self:build_input()
end

-- Called when the user presses a keyboard key while the console is active.
function chat_box:on_key_pressed(key, modifiers)

  if key == 'tab' then
    self.focused = not self.focused
  end

  if not self.focused then
    return
  end

  if key == "backspace" then
    self:remove_chars()
  elseif key == "delete" then
    self:remove_chars(true)
  elseif key == "return" or key == "kp return" then
      self:send_line()
  elseif key == "left" then
    self:shift_cursor(modifiers.control and -10 or -1, modifiers.shift)
  elseif key == "right" then
    self:shift_cursor(modifiers.control and 10 or 1, modifiers.shift)
  elseif key == "home" then
    self.cursor = 0
    if not modifiers.shift then
      self.selection = 0
    end
    -- rebuild selection surface
    self:build_selection()
  elseif key == "end" then
    self.cursor = #self:get_current_line()
    if not modifiers.shift then
      self.selection = self.cursor
    end
    -- rebuild selection surface
    self:build_selection()
  elseif key == "up" then
    self:shift_history(modifiers.control and -10 or -1)
  elseif key == "down" then
    self:shift_history(modifiers.control and 10 or 1)
  elseif key == "x" and modifiers.control then
    if self:copy_to_clipboard() then
      self:remove_chars()
    end
  elseif key == "c" and modifiers.control then
    self:copy_to_clipboard()
  elseif key == "v" and modifiers.control then
    self:paste_from_clipboard()
  end

  return true --handle all events --handle all events
end

-- Called when the user enters text while the console is active.
function chat_box:on_character_pressed(character)
  if not self.focused then
    return
  end
  local handled = false
  if not character:find("%c") then
    self:append_char(character)
    handled = true
  end

  return handled
end

function chat_box:on_draw(srf)
  --TODO draw everything
  self.background_surface:draw(srf,self.x,self.y)
  local mx,my = self.x+self.margin,self.y+self.margin
  self.messages_surf:draw(srf,mx,my)
  self.channel_surf:draw(srf,self.x+self.margin,self.y+self.input_y)
  self.input_surf:draw(
    srf,
    self.x+self.input_x,
    self.y+self.input_y-3)
  if self.focused then
    local cx,cy = self:cursor_position()
    self.cursor_sprite:draw(srf,self.x+cx,self.y+cy)
  end
end

function chat_box:get_surface()
  return {
    set_opacity = function()
      --TODO modify opacity here
    end
  }
end

function chat_box:__index(k)
  return rawget(self,k) or chat_box[k]
end

function chat_box:new(game,config)
  local cb = {
    x=config.x,
    y=config.y,
    width=config.width,
    height=config.height
  }
  setmetatable(cb,chat_box)
  cb:init()
  return cb
end

return chat_box

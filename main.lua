                                                                                   
                                                                             
local function fail(message) assert(false, tostring(message)) end
local previous = _G.Thalassar
local previousAppearance, previousEffects, previousSection, previousValues, previousVisible
local previousCrosshairs, previousWorld
if previous and previous.menu and type(previous.menu.exportAppearance)=="function" then
    local ok, value = pcall(previous.menu.exportAppearance)
    if ok then previousAppearance=value end
    local stateOK,state=pcall(previous.menu.status)
    if stateOK then previousSection=state.section; previousVisible=state.visible end
    if previous.uiVersion==2 and type(previous.menu.exportValues)=="function" then
        local valuesOK,values=pcall(previous.menu.exportValues)
        if valuesOK then previousValues=values end
    end
end
if previousAppearance and previous.uiVersion~=2 then
    if previousAppearance.Font==0 then previousAppearance.Font=1 end
    if previousAppearance.Opacity==.74 then previousAppearance.Opacity=.64 end
    if previousAppearance.BodyOpacity==.18 then previousAppearance.BodyOpacity=.12 end
    if previousAppearance.Rounding==19 then previousAppearance.Rounding=24 end
end
if previous and previous.effects and type(previous.effects.export)=="function" then
    local ok, value = pcall(previous.effects.export)
    if ok then previousEffects=value end
end
for _,entry in ipairs({{"crosshairs","crosshairs"},{"worldVisuals","world"}}) do
    local module=previous and previous[entry[1]]
    if module and type(module.export)=="function" then
        local ok,value=pcall(module.export)
        if ok then if entry[2]=="world" then previousWorld=value else previousCrosshairs=value end end
    end
end
if previous and type(previous.stop) == "function" then pcall(previous.stop) end
local builtinUI = UI
local Http = game:GetService("HttpService")
local uiFaults, lastProfileResult = {}, ""
local controller, renderConnection, stopped
local function uiError(where, message)
    local text = tostring(message)
    if uiFaults[where] ~= text then warn("[Thalassar Private] " .. where .. ": " .. text) end
    uiFaults[where] = text
end
local createGlass = (function()
                                                                         
                                                                                    
local function createThalassarUI(ctx)
    ctx = ctx or {}
    local rgb, v2 = Color3.fromRGB, Vector2.new
    local clamp, floor, min, max = math.clamp, math.floor, math.min, math.max
    local unpackValues = table.unpack or unpack
    local ui, tabs, pages, ids, objects, lastFrame = {}, {}, {}, {}, {}, {}
    local st = {alive=true, open=ctx.visible~=false, x=80, y=80, w=900, h=650,
        mx=0, my=0, prevMouse=false, prevMenu=false, prevKeys={}, time=0, count=0,
        group="Visuals", active=nil, initialized=false, visibility=ctx.visible~=false and 1 or 0,
        dt=.016, animation={}, pageFade=1, navScroll=0, navTarget=0, navMax=0, regions={}}
    local theme = {Scale=1, Opacity=.64, BodyOpacity=.12, Rounding=24,
        Tint={29,32,35,255}, Accent={147,171,182,255}, Text={237,239,240,255},
        FontSize=14, Font=1, Spacing=3, Grain=true, GrainStrength=.12,
        Glow=true, GlowStrength=.16, Particles=false, ParticleAmount=8,
        ParticleSpeed=.18, Vignette=false, VignetteStrength=.10,
        ReducedMotion=false, MenuKey=0x50, Specular=.42, Bevel=.24, AnimationSpeed=1}
    local defaultTheme = {}
    for k,v in pairs(theme) do defaultTheme[k]=type(v)=="table" and {unpackValues(v)} or v end
    local mouse = ctx.mouse
    if not mouse then pcall(function() mouse=game:GetService("Players").LocalPlayer:GetMouse() end) end
    local function safe(callback,...)
        if type(callback)~="function" then return true end
        local ok,err=pcall(callback,...)
        if not ok then st.error=tostring(err); if ctx.onError then pcall(ctx.onError,st.error) end end
        return ok
    end
    local function animate(id,target,speed,initial)
        local value=st.animation[id]
        if value==nil then value=initial~=nil and initial or target end
        if theme.ReducedMotion then value=target
        else value=value+(target-value)*(1-math.exp(-(speed or 20)*theme.AnimationSpeed*st.dt)) end
        if math.abs(value-target)<.001 then value=target end
        st.animation[id]=value
        return value
    end
    local function scrollToward(value,target)
        if theme.ReducedMotion then return target end
        value=value+(target-value)*(1-math.exp(-25*theme.AnimationSpeed*st.dt))
        return math.abs(value-target)<.03 and target or value
    end
    local drawOpacity,drawScale,drawCX,drawCY,drawDY,scopeOpacity,scopeDY=1,1,0,0,0,1,0
    local rawPaint=false
    local function point(x,y)
        if rawPaint then return x,y end
        return drawCX+(x-drawCX)*drawScale,drawCY+(y-drawCY)*drawScale+drawDY+scopeDY
    end
    local function alpha(a) return clamp((a or 1)*(rawPaint and 1 or drawOpacity*scopeOpacity),0,1) end
    local function dimension(v) return v*(rawPaint and 1 or drawScale) end
    local function col(v) return rgb(clamp(v[1] or 0,0,255),clamp(v[2] or 0,0,255),clamp(v[3] or 0,0,255)) end
    local function mix(a,b,t) return rgb((a.R+(b.R-a.R)*t)*255,(a.G+(b.G-a.G)*t)*255,(a.B+(b.B-a.B)*t)*255) end
    local function hit(x,y,w,h) return st.mx>=x and st.mx<=x+w and st.my>=y and st.my<=y+h end
    local function key(vk)
        if type(iskeypressed)~="function" then return false end
        local ok,value=pcall(iskeypressed,vk); return ok and value==true
    end
    local function focused()
        if ctx.focused then local ok,v=pcall(ctx.focused); return ok and v==true end
        if type(isrbxactive)=="function" then local ok,v=pcall(isrbxactive); return ok and v==true end
        return true
    end
    local function typing()
        if not ctx.typing then return false end
        local ok,v=pcall(ctx.typing); return not ok or v==true
    end
    local function viewport()
        if ctx.viewport then
            local ok,a,b=pcall(ctx.viewport)
            if ok and type(a)=="number" then return a,b end
            if ok and a then return a.X,a.Y end
        end
        local ok,v=pcall(function() return workspace.CurrentCamera.ViewportSize end)
        if ok and v then return v.X,v.Y end
        return 1920,1080
    end
                                                                                     
    local function drawing(frame,name,kind)
        local d=objects[name]
        if not d then
            d=Drawing.new(kind); assert(d,"Unable to create Thalassar "..kind)
            objects[name]=d; st.count=st.count+1; d.Visible=false
            if kind~="Text" then d.Thickness=1 end
        end
        frame[name]=true; return d
    end
    local function rect(f,id,x,y,w,h,c,a,r,z,outline)
        if w<=0 or h<=0 then return end
        local d=drawing(f,id,"Square")
        x,y=point(x,y)
        d.Position=v2(x,y); d.Size=v2(dimension(w),dimension(h)); d.Color=c; d.Transparency=alpha(a)
        d.Corner=dimension(r or 0); d.Filled=not outline; d.ZIndex=z or 100; d.Visible=true
    end
    local function roundedStroke(f,id,x,y,w,h,c,a,r,thickness,z)
        rect(f,id,x,y,w,h,c,a,r,z,true)
        local d=objects[id]
        if d then d.Thickness=dimension(thickness or 1) end
    end
    local function circle(f,id,x,y,r,c,a,z,outline)
        local d=drawing(f,id,"Circle")
        x,y=point(x,y)
        d.Position=v2(x,y); d.Radius=dimension(r); d.Color=c; d.Transparency=alpha(a)
        d.Filled=not outline; d.NumSides=24; d.ZIndex=z or 100; d.Visible=true
    end
    local function line(f,id,x1,y1,x2,y2,c,a,z)
        local d=drawing(f,id,"Line")
        x1,y1=point(x1,y1); x2,y2=point(x2,y2)
        d.From=v2(x1,y1); d.To=v2(x2,y2); d.Color=c; d.Transparency=alpha(a)
        d.ZIndex=z or 100; d.Visible=true
    end
    local function text(f,id,value,x,y,size,c,a,z,width,bold,alignment)
        value=tostring(value or "")
        if width then local chars=floor(width/(size*.52)); if #value>chars and chars>4 then value=value:sub(1,chars-3).."..." end end
        local d=drawing(f,id,"Text")
        d.Text=value; d.Size=dimension(size); d.Font=bold and 2 or theme.Font
        if alignment=="right" and width then
            local measured=#value*size*.52
            local ok,bounds=pcall(function() return d.TextBounds end)
            if ok and bounds and type(bounds.X)=="number" and bounds.X>0 then measured=bounds.X/(rawPaint and 1 or drawScale) end
            x=x+max(0,width-measured)
        end
        x,y=point(x,y)
        d.Position=v2(x,y); d.Color=c; d.Transparency=alpha((a or 1)*(theme.Text[4]/255))
        d.Center=false; d.Outline=false; d.ZIndex=z or 120; d.Visible=true
    end
    local function finish(frame)
        for id in pairs(lastFrame) do if not frame[id] then objects[id].Visible=false end end
        lastFrame=frame
    end
    local function hide()
        for id in pairs(lastFrame) do objects[id].Visible=false end
        lastFrame={}
    end
    local function fire(row)
        if row.kind=="Color" then safe(row.callback,col(row.value),row.value[4]/255)
        else safe(row.callback,row.value) end
    end
    local function colorValues(a,b,c,d)
        local byteArray=false
        if type(a)=="table" or type(a)=="userdata" then
            local ok,red,green,blue=pcall(function() return a.R,a.G,a.B end)
            if ok and type(red)=="number" then a,b,c,d=red,green,blue,b
            else byteArray=true; a,b,c,d=a[1],a[2],a[3],a[4] or b end
        end
        a,b,c,d=tonumber(a) or 255,tonumber(b) or 255,tonumber(c) or 255,tonumber(d) or 255
        if not byteArray and a<=1 and b<=1 and c<=1 then a,b,c=a*255,b*255,c*255 end
        if not byteArray and d<=1 then d=d*255 end
        return {clamp(a,0,255),clamp(b,0,255),clamp(c,0,255),clamp(d,0,255)}
    end
    local function set(row,notify,...)
        local args={...}; local v=args[1]
        if row.kind=="Color" then row.value=colorValues(unpackValues(args))
        elseif row.kind=="Toggle" then row.value=v==true
        elseif row.kind=="Slider" then
            row.value=clamp(tonumber(v) or row.min,row.min,row.max)
            if row.step>0 then row.value=clamp(floor(row.value/row.step+.5)*row.step,row.min,row.max) end
        elseif row.kind=="Combo" then row.value=clamp(floor(tonumber(v) or 0),0,max(0,#row.items-1))
        elseif row.kind=="Keybind" then row.value=clamp(floor(tonumber(v) or 0),0,255)
        elseif row.kind=="InputText" or row.kind=="Label" then row.value=tostring(v or ""); if row.kind=="Label" then row.label=row.value end
        else row.value=v end
        if notify then fire(row) end
        return row
    end
    local serial=0
    local function add(page,kind,id,label,value,callback,opt)
        serial=serial+1; opt=opt or {}; id=tostring(id or "thalassar_control_"..serial)
        assert(not ids[id],"Duplicate control ID: "..id)
        local row={id=id,kind=kind,label=tostring(label or id),value=value,callback=callback,
            hidden=opt.Hidden==true,enabled=opt.Enabled~=false,tip=opt.Tooltip,page=page}
        function row:SetValue(...) return set(self,false,...) end
        function row:SetText(value) return set(self,false,value) end
        function row:GetValue() if self.kind=="Color" then return unpackValues(self.value) end; if self.kind=="Keybind" then return self:IsEnabled() end; return self.value end
        function row:GetText() return self.kind=="Combo" and (self.items[self.value+1] or "") or tostring(self.value or "") end
        function row:SetTitle(v) self.label=tostring(v); return self end
        function row:SetVisible(v) self.hidden=v~=true; return self end
        function row:SetDisabled(v) self.enabled=not v; return self end
        function row:Tip(v) self.tip=tostring(v); return self end
        function row:Clear() if self.kind=="Combo" then self.items={}; self.value=0 end; return self end
        function row:Add(v) if self.kind=="Combo" then self.items[#self.items+1]=v end; return self end
        function row:AddToHotkey(label,toggleId) self.hotkeyLabel,self.toggleId=label,toggleId; return self end
        function row:IsEnabled()
            if self.kind~="Keybind" then return self.enabled end
            return self.boundOn==true
        end
        ids[id]=row; page.rows[#page.rows+1]=row; return row
    end
    local methods={}
    function methods:Toggle(id,label,value,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,value,cb=o.Id,o.Title,o.Default,o.Callback end
        if type(value)=="function" then cb,value=value,false end
        return add(self,"Toggle",id,label,value==true,cb,o)
    end
    function methods:Slider(id,label,minimum,maximum,value,cb,step)
        local o=type(id)=="table" and id or nil
        if o then id,label,minimum,maximum,value,cb,step=o.Id,o.Title,o.Min,o.Max,o.Default,o.Callback,o.Step end
        local row=add(self,"Slider",id,label,tonumber(value) or 0,cb,o)
        row.min,row.max,row.step=tonumber(minimum) or 0,tonumber(maximum) or 100,tonumber(step) or 1
        assert(row.max>=row.min,"Invalid slider range: "..row.id); set(row,false,row.value); return row
    end
    function methods:SliderInt(id,label,minimum,maximum,value,cb) return self:Slider(id,label,minimum,maximum,value,cb,1) end
    function methods:SliderFloat(id,label,minimum,maximum,value,format,cb)
        if type(format)=="function" then cb,format=format,nil end
        local row=self:Slider(id,label,minimum,maximum,value,cb,.01); row.format=format or "%.2f"; return row
    end
    function methods:Combo(id,label,items,value,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,items,value,cb=o.Id,o.Title,o.Options or o.Items,o.Default,o.Callback end
        if type(items)=="number" and type(value)=="table" then items,value=value,items end
        local row=add(self,"Combo",id,label,tonumber(value) or 0,cb,o)
        row.items=type(items)=="table" and items or {}; set(row,false,row.value); return row
    end
    methods.Dropdown=methods.Combo
    function methods:ColorPicker(id,r,g,b,a,cb,label)
        local o=type(id)=="table" and id or nil
        if o then id,label,cb=o.Id,o.Title,o.Callback; r,g,b,a=unpackValues(colorValues(o.Default or o.Color or {255,255,255},o.Alpha or 255)) end
        if not label then local prev=self.rows[#self.rows]; label=prev and prev.label.." color" or "Color" end
        return add(self,"Color",id,label,colorValues(r,g,b,a),cb,o)
    end
    function methods:Button(id,label,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,cb=o.Id,o.Title,o.Callback
        elseif type(label)=="function" then cb,label,id=label,id,nil end
        return add(self,"Button",id,label,nil,cb,o)
    end
    function methods:Keybind(id,label,vk,cb,mode)
        local o=type(id)=="table" and id or nil
        if o then id,label,vk,cb,mode=o.Id,o.Title,o.Default,o.Callback,o.Mode
        elseif type(label)=="number" then vk,mode,label=label,vk,"Shortcut" end
        local row=add(self,"Keybind",id,label or "Shortcut",tonumber(vk) or 0,cb,o); row.mode=mode or "toggle"; return row
    end
    function methods:InputText(id,label,value,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,value,cb=o.Id,o.Title,o.Default,o.Callback end
        return add(self,"InputText",id,label,tostring(value or ""),cb,o)
    end
    function methods:Label(id,label)
        local o=type(id)=="table" and id or nil
        if o then id,label=o.Id,o.Title elseif not label then label,id=id,nil end
        return add(self,"Label",id,label,tostring(label or ""),nil,o)
    end
    function methods:Tip(value) local row=self.rows[#self.rows]; if row then row.tip=tostring(value) end; return row end
    function methods:Heading(value) return add(self,"Heading",nil,value,nil,nil) end
    local groupOrder={"Visuals","Vehicle","Targeting","Utilities","Settings"}
    local function groupFor(title)
        title=string.lower(title)
        if title:find("config",1,true) or title:find("profile",1,true) or title:find("performance",1,true) or title:find("interface",1,true) or title:find("appearance",1,true) or title:find("background",1,true) then return "Settings" end
        if title:find("esp",1,true) or title:find("module",1,true) then return "Visuals" end
        if title:find("crosshair",1,true) or title:find("target",1,true) or title:find("aim",1,true) then return "Targeting" end
        if title:find("ammo",1,true) or title:find("armour",1,true) or title:find("crew",1,true) or title:find("vehicle",1,true) or title:find("rapid",1,true) then return "Vehicle" end
        return "Utilities"
    end
    function ui.AddTab(name,builder)
        local tab={name=tostring(name),sections={}}
        function tab:Section(title,opt)
            opt=type(opt)=="table" and opt or {}
            local page=setmetatable({title=tostring(title),group=opt.Group or groupFor(tostring(title)),rows={},scroll=0,targetScroll=0,tab=self,interface=opt.Interface==true},{__index=methods})
            pages[#pages+1]=page; self.sections[#self.sections+1]=page
            if not st.active or st.active.interface and not page.interface then st.active=page; st.group=page.group end
            return page
        end
        tabs[#tabs+1]=tab; if type(builder)=="function" then builder(tab) end; return tab
    end
    function ui.RemoveTab(name)
        for i=#pages,1,-1 do if pages[i].tab.name==name then for _,r in ipairs(pages[i].rows) do ids[r.id]=nil end; if st.active==pages[i] then st.active=nil end; table.remove(pages,i) end end
        for i=#tabs,1,-1 do if tabs[i].name==name then table.remove(tabs,i) end end
        if not st.active then st.active=pages[1]; if st.active then st.group=st.active.group end end
    end
    function ui.GetValue(id) local row=ids[id]; if row then return row:GetValue() end end
    function ui.SetValue(id,...) local row=ids[id]; if row then return set(row,false,...) end end
    function ui.visible() return st.open and st.alive end
    function ui.setVisible(value)
        value=value==true; if st.open==value then return end
        st.open=value; st.popup=nil; st.drag=nil; st.edit=nil; st.capture=nil
        if theme.ReducedMotion then st.visibility=value and 1 or 0; st.transition=nil; if not value then hide() end
        else st.transition={from=st.visibility,to=value and 1 or 0,time=0,duration=.22/theme.AnimationSpeed} end
        safe(ctx.onVisibility,value)
    end
    local function insideRegion(region,x,y)
        return region and x>=region.x and x<=region.x+region.w and y>=region.y and y<=region.y+region.h
    end
    function ui.scrollRegions()
        local out={}
        for name,region in pairs(st.regions) do
            out[name]={x=region.x,y=region.y,w=region.w,h=region.h,max=region.max or 0,
                current=region.current or 0,target=region.target or 0,scale=region.scale or 1}
        end
        return out
    end
    function ui.scroll(delta,x,y)
        delta=tonumber(delta)
        if not delta or delta~=delta or delta==0 or not st.alive or not st.open or st.visibility<.99 or not focused() or typing() then return false end
        delta=clamp(delta,-24,24)
        x=tonumber(x) or tonumber(mouse and mouse.X) or st.mx
        y=tonumber(y) or tonumber(mouse and mouse.Y) or st.my
        local region
        if st.popup then
            region=st.regions.dropdown
            if st.popup.kind=="Combo" and not st.popup.closing and insideRegion(region,x,y) then
                st.popup.scrollTarget=clamp((st.popup.scrollTarget or 0)-delta,0,max(0,#st.popup.row.items-8))
                region.target=st.popup.scrollTarget
                return true,"dropdown"
            end
            return false
        end
        region=st.regions.sidebar
        if insideRegion(region,x,y) then
            st.navTarget=clamp(st.navTarget-delta*34*region.scale,0,st.navMax)
            region.target=st.navTarget
            return true,"sidebar"
        end
        region=st.regions.page
        if region and region.page==st.active and insideRegion(region,x,y) then
            st.active.targetScroll=clamp(st.active.targetScroll-delta*34*region.scale,0,region.max)
            region.target=st.active.targetScroll
            return true,"page"
        end
        return false
    end
    function ui.isInteracting() return st.alive and st.open and focused() and not typing() end
    function ui.selectSection(name)
        for _,p in ipairs(pages) do if p.title==name then
            if st.active~=p then st.pageFade=theme.ReducedMotion and 1 or 0 end
            st.active=p; st.group=p.group; st.popup=nil; st.regions={}; return true
        end end
        return false
    end
    function ui.exportValues()
        local out={}
        for id,row in pairs(ids) do if row.kind~="Button" and row.kind~="Heading" and row.kind~="Label" then out[id]=type(row.value)=="table" and {unpackValues(row.value)} or row.value end end
        return out
    end
    function ui.importValues(values,notify)
        if type(values)~="table" then return false end
        for id,value in pairs(values) do local row=ids[id]; if row then set(row,notify==true,value) end end
        return true
    end
    local settingRows={}
    function ui.exportAppearance()
        local out={}; for name,value in pairs(theme) do out[name]=type(value)=="table" and {unpackValues(value)} or value end
        out.Window={st.x,st.y,st.w,st.h}; return out
    end
    function ui.importAppearance(saved)
        if type(saved)~="table" then return false end
        for name,row in pairs(settingRows) do if saved[name]~=nil then set(row,true,saved[name]) end end
        if type(saved.Window)=="table" then local w=saved.Window; st.x=tonumber(w[1]) or st.x; st.y=tonumber(w[2]) or st.y; st.w=clamp(tonumber(w[3]) or st.w,700,1400); st.h=clamp(tonumber(w[4]) or st.h,480,1000); st.initialized=true end
        return true
    end
    function ui.resetAppearance() return ui.importAppearance(defaultTheme) end
    function ui.status() return {name="Thalassar Private",alive=st.alive,visible=st.open,minimized=st.alive and not st.open,section=st.active and st.active.title,drawings=st.count,error=st.error,backdropBlur=false,width=st.w,height=st.h,opacity=st.visibility,animating=st.transition~=nil,font=theme.Font} end
    function ui.destroy()
        if not st.alive then return end
        st.alive=false; st.open=false; st.drag=nil; st.popup=nil; st.capture=nil; st.edit=nil
        safe(ctx.onVisibility,false); for _,d in pairs(objects) do pcall(function() d:Remove() end) end
        objects={}; lastFrame={}; st.count=0
    end
    local function keyName(code)
        if code>=65 and code<=90 or code>=48 and code<=57 then return string.char(code) end
        if code>=112 and code<=135 then return "F"..tostring(code-111) end
        local names={[0]="None",[27]="Esc",[32]="Space",[9]="Tab",[13]="Enter",[16]="Shift",[17]="Ctrl",[18]="Alt",[45]="Insert",[46]="Delete",[36]="Home",[35]="End",[33]="Page Up",[34]="Page Down"}
        return names[code] or string.format("0x%02X",code)
    end
    local function rowHeight(row,s)
        if row.hidden then return 0 end
        return (row.kind=="Slider" and 56 or row.kind=="Heading" and 31 or row.kind=="Label" and 36 or 43)*s
    end
    local function sliderSet(row,x,w) set(row,true,row.min+(row.max-row.min)*clamp((st.mx-x)/max(w,1),0,1)) end
    local function number(row)
        if row.format then local ok,v=pcall(string.format,row.format,row.value); if ok then return v end end
        return row.step>=1 and tostring(floor(row.value+.5)) or string.format("%.2f",row.value)
    end
    local function primeEditKeys() for vk=8,222 do st.prevKeys[vk]=key(vk) end end
    local function drawRow(f,row,x,y,w,s,c,click,input,bottom)
        local id,h,font=row.id,rowHeight(row,s),theme.FontSize*s
        local hover=input and hit(x,y,w,h); local opacity=row.enabled and 1 or .4
        local highlight=animate(id..":hoverAnimation",hover and not st.popup and 1 or 0,23,0)
        row.bounds={x=x,y=y,w=w,h=h}
        if row.kind=="Heading" or row.kind=="Label" then
            text(f,id..":label",row.label,x+12*s,y+9*s,font-s,c.text,.58,120,w-24*s,row.kind=="Heading"); return
        end
        if highlight>.001 then rect(f,id..":hover",x+3*s,y+s,w-6*s,h-2*s,c.white,.075*highlight,8*s,116) end
        local labelW=w-120*s
        if row.kind=="Combo" or row.kind=="InputText" then labelW=w-260*s end
        if row.kind~="Button" then text(f,id..":name",row.label,x+12*s,y+12*s,font,c.text,.93*opacity,120,labelW) end
        local right=x+w-14*s
        if row.kind=="Toggle" then
            local tx,ty=right-35*s,y+12*s
            local on=animate(id..":toggleAnimation",row.value and 1 or 0,24,row.value and 1 or 0)
            rect(f,id..":track",tx,ty,35*s,18*s,mix(c.white,c.accent,on),(.12+.68*on)*opacity,9*s,120)
            circle(f,id..":knobShadow",tx+(9+17*on)*s,ty+10*s,6.5*s,c.black,.15*opacity,121)
            circle(f,id..":knob",tx+(9+17*on)*s,ty+9*s,6*s,mix(c.muted,c.text,on),opacity,122)
            circle(f,id..":knobHighlight",tx+(9+17*on)*s,ty+8*s,5*s,c.white,(.12+.13*highlight)*opacity,123)
            if click and hover and row.enabled and not st.popup then set(row,true,not row.value) end
        elseif row.kind=="Slider" then
            text(f,id..":number",number(row),right-100*s,y+12*s,font,c.text,.72*opacity,120,100*s,false,"right")
            local sx,sy,sw=x+14*s,y+40*s,w-28*s
            local targetRatio=row.max==row.min and 0 or (row.value-row.min)/(row.max-row.min)
            local ratio=animate(id..":sliderAnimation",targetRatio,34,targetRatio)
            rect(f,id..":range",sx,sy,sw,3*s,c.white,.10*opacity,2*s,120)
            rect(f,id..":fill",sx,sy,max(1,sw*ratio),3*s,c.accent,.85*opacity,2*s,122)
            circle(f,id..":handleShadow",sx+sw*ratio,sy+2.5*s,6*s,c.black,.20*opacity,123)
            circle(f,id..":handle",sx+sw*ratio,sy+1.5*s,(5+highlight)*s,c.text,opacity,124)
            if click and row.enabled and hit(sx-5*s,sy-10*s,sw+10*s,20*s) and not st.popup then st.drag={kind="slider",row=row,x=sx,w=sw}; sliderSet(row,sx,sw) end
        elseif row.kind=="Combo" or row.kind=="InputText" then
            local bx,by,bw,bh=right-235*s,y+7*s,235*s,29*s
            rect(f,id..":box",bx,by,bw,bh,c.white,(.045+.055*highlight)*opacity,7*s,120)
            rect(f,id..":border",bx,by,bw,bh,c.white,(.10+.12*highlight)*opacity,7*s,121,true)
            local value=row:GetText()
            if st.edit and st.edit.row==row then value=st.edit.buffer..(floor(st.time*2)%2==0 and "|" or "") end
            text(f,id..":value",value,bx+10*s,by+7*s,font,c.text,.82*opacity,124,bw-35*s)
            if row.kind=="Combo" then
                line(f,id..":chevronA",right-18*s,by+12*s,right-14*s,by+16*s,c.text,.5,125)
                line(f,id..":chevronB",right-14*s,by+16*s,right-10*s,by+12*s,c.text,.5,125)
            end
            if click and row.enabled and hit(bx,by,bw,bh) and not st.popup then
                if row.kind=="Combo" then
                    local ph=(min(#row.items,8)*32+12+(#row.items>8 and 28 or 0))*s; local py=by+bh+4*s
                    if py+ph>bottom then py=max(st.y+65*s,by-ph-4*s) end
                    st.popup={kind="Combo",row=row,x=bx,y=py,w=bw,scroll=0,scrollTarget=0,justOpened=true,fade=0}
                else st.edit={row=row,buffer=row.value}; primeEditKeys() end
            end
        elseif row.kind=="Color" then
            local bx,by=right-44*s,y+9*s
            rect(f,id..":swatch",bx,by,44*s,25*s,col(row.value),opacity,6*s,120)
            rect(f,id..":swatchBorder",bx,by,44*s,25*s,c.white,(.25+.35*highlight)*opacity,6*s,122,true)
            if click and row.enabled and hit(bx-5*s,by-4*s,54*s,33*s) and not st.popup then
                local pw,ph,py=285*s,206*s,by+34*s
                if py+ph>bottom then py=max(st.y+65*s,by-ph-5*s) end
                st.popup={kind="Color",row=row,x=right-pw,y=py,w=pw,justOpened=true,fade=0}
            end
        elseif row.kind=="Button" then
            rect(f,id..":button",x+12*s,y+5*s,w-24*s,32*s,c.white,.045+.065*highlight,8*s,120)
            rect(f,id..":buttonBorder",x+12*s,y+5*s,w-24*s,32*s,c.white,.11+.12*highlight,8*s,121,true)
            text(f,id..":buttonText",row.label,x+24*s,y+13*s,font,c.text,.85*opacity,124,w-54*s)
            if click and hover and row.enabled and not st.popup then safe(row.callback) end
        elseif row.kind=="Keybind" then
            local bx,by,bw=right-112*s,y+7*s,112*s
            rect(f,id..":bind",bx,by,bw,29*s,c.white,.045+.075*highlight,7*s,120)
            rect(f,id..":bindBorder",bx,by,bw,29*s,c.white,.09+.09*highlight,7*s,121,true)
            text(f,id..":key",st.capture==row and "Press a key..." or keyName(row.value),bx+10*s,by+7*s,font-s,c.text,.7,123,bw-15*s)
            if click and row.enabled and hit(bx,by,bw,29*s) and not st.popup then st.capture=row; primeEditKeys() end
        end
        if row.tip and hover and not st.popup and not st.drag then st.tip=row.tip end
    end
    local function drawPopup(f,c,s,click,input)
        local p=st.popup; if not p then return end
        local target=p.closing and 0 or 1
        p.fade=theme.ReducedMotion and target or p.fade+(target-p.fade)*(1-math.exp(-24*theme.AnimationSpeed*st.dt))
        if p.closing and p.fade<.005 then st.popup=nil; return end
        local x,y,w=p.x,p.y,p.w
        local h=p.kind=="Combo" and (min(#p.row.items,8)*32+12+(#p.row.items>8 and 28 or 0))*s or 206*s
        if p.kind=="Combo" and #p.row.items==0 then h=44*s end
        if click and input and not p.justOpened and not hit(x,y,w,h) then p.closing=true end
        local popupClick=click and not p.justOpened and not p.closing
        p.justOpened=false
        local oldScope,oldDY=scopeOpacity,scopeDY
        scopeOpacity=oldScope*p.fade; scopeDY=oldDY+(1-p.fade)*4*s
        local popupX,popupY=point(x,y)
        st.regions.dropdown={x=popupX,y=popupY,w=dimension(w),h=dimension(h),max=max(0,#(p.row.items or {})-8),current=p.scroll or 0,target=p.scrollTarget or 0,scale=s*drawScale}
        rect(f,"popup:shadow",x-3*s,y+3*s,w+6*s,h+6*s,c.black,.3,10*s,300)
        rect(f,"popup:body",x,y,w,h,mix(c.tint,c.black,.1),.98,9*s,301)
        rect(f,"popup:edge",x,y,w,h,c.white,.12,9*s,302,true)
        if p.kind=="Combo" then
            p.scrollTarget=clamp(p.scrollTarget or 0,0,max(0,#p.row.items-8))
            p.scroll=scrollToward(p.scroll or 0,p.scrollTarget)
            st.regions.dropdown.current=p.scroll; st.regions.dropdown.target=p.scrollTarget
            local first=floor(p.scroll); local fraction=p.scroll-first
            for i=1,min(9,#p.row.items-first) do
                local index=i+first; local oy=y+6*s+((i-1)-fraction)*32*s
                if oy>=y+6*s-.01 and oy+31*s<=y+6*s+min(8,#p.row.items)*32*s then
                local over=input and not p.closing and hit(x+5*s,oy,w-10*s,32*s)
                local hover=animate("popup:optionHover:"..i,over and 1 or 0,23,0)
                local selected=p.row.value==index-1 and 1 or 0
                if hover>.001 or selected==1 then rect(f,"popup:option:"..i,x+5*s,oy,w-10*s,31*s,c.accent,.11*selected+.13*hover,6*s,303) end
                text(f,"popup:text:"..i,p.row.items[index],x+12*s,oy+9*s,theme.FontSize*s,c.text,.9,306,w-24*s)
                if popupClick and over then set(p.row,true,index-1); p.closing=true end
                end
            end
            if #p.row.items>8 then
                local fy=y+h-27*s
                text(f,"popup:range",tostring(first+1).."-"..tostring(min(#p.row.items,first+8)).." / "..tostring(#p.row.items),x+12*s,fy+7*s,10*s,c.text,.40,306,w-100*s)
                text(f,"popup:previous","Up",x+w-76*s,fy+6*s,11*s,c.text,.65,306,27*s)
                text(f,"popup:next","Down",x+w-45*s,fy+6*s,11*s,c.text,.65,306,36*s)
                if popupClick and hit(x+w-80*s,fy,33*s,24*s) then p.scrollTarget=max(0,p.scrollTarget-8) end
                if popupClick and hit(x+w-47*s,fy,42*s,24*s) then p.scrollTarget=min(max(0,#p.row.items-8),p.scrollTarget+8) end
                local up,down=key(33),key(34)
                if input and up and not p.prevUp then p.scrollTarget=max(0,p.scrollTarget-8) end
                if input and down and not p.prevDown then p.scrollTarget=min(max(0,#p.row.items-8),p.scrollTarget+8) end
                p.prevUp,p.prevDown=up,down
            end
        else
            local row=p.row
            text(f,"popup:title",row.label,x+14*s,y+13*s,theme.FontSize*s,c.text,.9,306,w-72*s,true)
            rect(f,"popup:preview",x+w-52*s,y+10*s,37*s,24*s,col(row.value),1,5*s,306)
            for i,label in ipairs({"Red","Green","Blue","Opacity"}) do
                local oy=y+(49+(i-1)*36)*s; local sx,sy,sw=x+82*s,oy+5*s,w-144*s
                text(f,"popup:channel:"..i,label,x+14*s,oy-3*s,theme.FontSize*s-2*s,c.text,.58,306,56*s)
                text(f,"popup:number:"..i,tostring(floor(row.value[i]+.5)),x+w-43*s,oy-3*s,theme.FontSize*s-2*s,c.text,.7,306,40*s)
                rect(f,"popup:track:"..i,sx,sy,sw,3*s,c.white,.12,2*s,306)
                rect(f,"popup:fill:"..i,sx,sy,max(1,sw*row.value[i]/255),3*s,c.accent,.8,2*s,307)
                circle(f,"popup:handle:"..i,sx+sw*row.value[i]/255,sy+1.5*s,4*s,c.text,1,308)
                if popupClick and input and hit(sx-4*s,oy-8*s,sw+8*s,25*s) then
                    st.drag={kind="color",row=row,index=i,x=sx,w=sw}
                    local values={unpackValues(row.value)}
                    values[i]=floor(clamp((st.mx-sx)/sw,0,1)*255+.5)
                    set(row,true,values)
                end
            end
            text(f,"popup:foot","Click outside to close",x+14*s,y+h-19*s,10*s,c.text,.36,306,w-28*s)
        end
        scopeOpacity,scopeDY=oldScope,oldDY
    end
    local function consumeWheel()
        if type(ctx.consumeWheel)~="function" then return end
        local ok,delta,x,y=pcall(ctx.consumeWheel)
        if ok then
            local handled,region=ui.scroll(delta,x,y)
            if tonumber(delta) and delta~=0 then safe(ctx.onWheelConsumed,handled,region,delta,x,y) end
        else st.error=tostring(delta); safe(ctx.onError,st.error) end
    end
    local function updateKeys(input)
        local menu=key(theme.MenuKey); local edge=menu and not st.prevMenu; st.prevMenu=menu
        if input and edge and not st.capture and not st.edit then ui.setVisible(not st.open) end
        if input and (st.capture or st.edit) then
            local shift=key(16) or key(160) or key(161)
            for vk=8,222 do
                local held=key(vk); local pressed=held and not st.prevKeys[vk]; st.prevKeys[vk]=held
                if pressed then
                    if st.capture then local row=st.capture; st.capture=nil; if vk~=27 then set(row,true,vk) end; break
                    elseif st.edit then
                        local edit=st.edit
                        if vk==27 then st.edit=nil; break
                        elseif vk==13 then set(edit.row,true,edit.buffer); st.edit=nil; break
                        elseif vk==8 then edit.buffer=edit.buffer:sub(1,max(0,#edit.buffer-1))
                        elseif #edit.buffer<120 then
                            local char
                            if vk>=65 and vk<=90 then char=string.char(shift and vk or vk+32)
                            elseif vk>=48 and vk<=57 then char=shift and (")!@#$%^&*("):sub(vk-47,vk-47) or string.char(vk)
                            elseif vk==32 then char=" "
                            else local chars={[186]={";",":"},[187]={"=","+"},[188]={",","<"},[189]={"-","_"},[190]={".",">"},[191]={"/","?"},[192]={"`","~"},[219]={"[","{"},[220]={"\\","|"},[221]={"]","}"},[222]={"'",'"'}}; if chars[vk] then char=chars[vk][shift and 2 or 1] end end
                            if char then edit.buffer=edit.buffer..char end
                        end
                    end
                end
            end
        end
        for _,row in pairs(ids) do if row.kind=="Keybind" and row.value~=0 then
            local held=key(row.value); local pressed=held and not row.prevHeld; row.prevHeld=held
            if input and not st.open then
                if row.mode=="hold" then row.boundOn=held elseif pressed then row.boundOn=not row.boundOn end
            elseif row.mode=="hold" then
                row.boundOn=false
            end
        end end
    end
    function ui.step(dt)
        if not st.alive then return end
        dt=clamp(tonumber(dt) or .016,0,.1); st.time=st.time+dt; st.dt=dt
        local vw,vh=viewport()
        if not st.initialized then st.initialized=true; st.x=max(12,(vw-st.w)/2); st.y=max(12,(vh-st.h)/2) end
        st.mx=tonumber(mouse and mouse.X) or st.mx; st.my=tonumber(mouse and mouse.Y) or st.my
        local down=type(ismouse1pressed)=="function" and ismouse1pressed()==true or false
        local input=focused() and not typing(); local click=down and not st.prevMouse and input
        st.prevMouse=down; updateKeys(input); consumeWheel()
        if st.transition then
            local transition=st.transition
            transition.time=min(transition.duration,transition.time+dt)
            local t=transition.time/transition.duration
            local eased=t*t*(3-2*t)
            st.visibility=transition.from+(transition.to-transition.from)*eased
            if t>=1 or theme.ReducedMotion then st.visibility=transition.to; st.transition=nil end
        end
        if not st.open and st.visibility<=.001 then hide(); st.drag=nil; return end
        input=input and st.open and st.visibility>.99
        click=click and input
        if not input then st.drag=nil; st.capture=nil; st.edit=nil end
        local targetScale=clamp(theme.Scale,.75,1.5)
        local s=animate("glass:scaleAnimation",targetScale,27,targetScale)
        local maxW,maxH=max(470,(vw-24)/s),max(350,(vh-24)/s)
        st.w=clamp(st.w,min(700,maxW),maxW); st.h=clamp(st.h,min(480,maxH),maxH)
        local w,h=st.w*s,st.h*s
        st.x=clamp(st.x,12,max(12,vw-w-12)); st.y=clamp(st.y,12,max(12,vh-h-12))
        if st.drag and input then
            local d=st.drag
            if not down then st.drag=nil
            elseif d.kind=="window" then st.x=st.mx-d.dx; st.y=st.my-d.dy
            elseif d.kind=="resize" then st.w=(st.mx-st.x+d.dx)/s; st.h=(st.my-st.y+d.dy)/s
            elseif d.kind=="slider" then sliderSet(d.row,d.x,d.w)
            elseif d.kind=="color" then local v={unpackValues(d.row.value)}; v[d.index]=floor(clamp((st.mx-d.x)/d.w,0,1)*255+.5); set(d.row,true,v)
            elseif d.kind=="scroll" then
                st.active.targetScroll=clamp((st.my-d.y)/d.h,0,1)*d.maximum; st.active.scroll=st.active.targetScroll
            elseif d.kind=="navscroll" then
                st.navTarget=clamp((st.my-d.y)/d.h,0,1)*d.maximum; st.navScroll=st.navTarget
            end
        end
        local x,y,r=st.x,st.y,animate("glass:roundingAnimation",theme.Rounding,24,theme.Rounding)*s
        w,h=st.w*s,st.h*s
        drawOpacity=st.visibility; drawScale=theme.ReducedMotion and 1 or .965+.035*st.visibility
        drawCX,drawCY,drawDY=x+w/2,y+h/2,theme.ReducedMotion and 0 or (1-st.visibility)*12*s
        scopeOpacity,scopeDY,rawPaint=1,0,false
        st.regions={}
        local windowX,windowY=point(x,y)
        st.regions.window={x=windowX,y=windowY,w=dimension(w),h=dimension(h),scale=s*drawScale}
        if theme.ReducedMotion then st.pageFade=1 else st.pageFade=st.pageFade+(1-st.pageFade)*(1-math.exp(-22*theme.AnimationSpeed*dt)) end
        local f={}; local c={tint=col(theme.Tint),accent=col(theme.Accent),text=col(theme.Text),white=rgb(255,255,255),black=rgb(0,0,0),muted=rgb(161,167,170)}
        st.tip=nil
        if theme.Glow then roundedStroke(f,"glass:glow",x-s,y-s,w+2*s,h+2*s,c.accent,theme.GlowStrength*.035,r+s,5*s,94) end
        roundedStroke(f,"glass:shadow",x-1.5*s,y-1.5*s,w+3*s,h+3*s,c.black,.12,r+1.5*s,4*s,95)
        rect(f,"glass:body",x,y,w,h,c.tint,animate("glass:opacityAnimation",theme.Opacity,24,theme.Opacity),r,100)
        roundedStroke(f,"glass:edge",x,y,w,h,c.white,.17+theme.Bevel*.16+theme.Specular*.12,r,s,104)
        rect(f,"glass:sheen",x+5*s,y+4*s,w-10*s,50*s,c.white,.014+theme.Specular*.055,max(0,r-4*s),103)
        line(f,"glass:reflection",x+r,y+s,x+w-r,y+s,c.white,.14+theme.Specular*.45,105)
        if theme.Grain then for i=1,38 do
            local gx=x+14*s+((i*127+i*i*19)%997/997)*(w-28*s); local gy=y+14*s+((i*173+i*i*7)%991/991)*(h-28*s)
            circle(f,"glass:grain:"..i,gx,gy,.55*s,c.white,theme.GrainStrength*.22,106)
        end end
        if theme.Particles then for i=1,floor(theme.ParticleAmount) do
            local t=theme.ReducedMotion and 0 or st.time*theme.ParticleSpeed
            local px=x+18*s+((i*193%997/997+t*(.015+i%4*.002))%1)*(w-36*s)
            local py=y+20*s+(i*139%991/991)*(h-40*s)+(theme.ReducedMotion and 0 or math.sin(t+i*1.1)*6*s)
            circle(f,"glass:particle:"..i,px,py,(1.2+i%2*.4)*s,c.white,.06+theme.GrainStrength*.15,107)
        end end
        if theme.Vignette then
            roundedStroke(f,"glass:vignette",x+5*s,y+5*s,w-10*s,h-10*s,c.black,theme.VignetteStrength*.30,max(0,r-5*s),3*s,107)
        end
        if ctx.drawBackgroundEffects then
            local fxX,fxY=point(x,y)
            local api={x=fxX,y=fxY,w=dimension(w),h=dimension(h),radius=dimension(r),scale=s*drawScale,
                dt=dt,time=st.time,opacity=st.visibility,reducedMotion=theme.ReducedMotion,colors=c}
            api.rect=function(id,px,py,pw,ph,color,opacity,radius,z,outline)
                rawPaint=true; rect(f,id,px,py,pw,ph,color,opacity,radius,z or 107,outline); rawPaint=false
            end
            api.circle=function(id,px,py,radius,color,opacity,z,outline)
                rawPaint=true; circle(f,id,px,py,radius,color,opacity,z or 107,outline); rawPaint=false
            end
            api.line=function(id,px,py,qx,qy,color,opacity,z)
                rawPaint=true; line(f,id,px,py,qx,qy,color,opacity,z or 107); rawPaint=false
            end
            safe(ctx.drawBackgroundEffects,api); rawPaint=false
            if not st.alive then return end
        end
        local side=196*s
        text(f,"header:name","Thalassar Private",x+24*s,y+20*s,(theme.FontSize+6)*s,c.text,.98,120,w-200*s,true)
        local cx,cy=x+w-30*s,y+30*s
        local mx,my=x+w-66*s,y+30*s
        local closeHover=input and hit(cx-15*s,cy-15*s,30*s,30*s)
        local minHover=input and hit(mx-15*s,my-15*s,30*s,30*s)
        local ca=animate("header:closeHover",closeHover and 1 or 0,24,0)
        local ma=animate("header:minHover",minHover and 1 or 0,24,0)
        if ca>.001 then rect(f,"header:closeHover",cx-15*s,cy-15*s,30*s,30*s,c.white,.11*ca,9*s,118) end
        if ma>.001 then rect(f,"header:minHover",mx-15*s,my-15*s,30*s,30*s,c.white,.10*ma,9*s,118) end
        line(f,"header:closeA",cx-7*s,cy-7*s,cx+7*s,cy+7*s,c.text,.82+.18*ca,122)
        line(f,"header:closeB",cx-7*s,cy+7*s,cx+7*s,cy-7*s,c.text,.82+.18*ca,122)
        line(f,"header:minimize",mx-7*s,my+2*s,mx+7*s,my+2*s,c.text,.78+.22*ma,122)
        if closeHover then st.tip="Unload script" elseif minHover then st.tip="Minimize interface" end
        if click and not st.popup and closeHover then
            safe(ctx.onClose)
            if st.alive then ui.destroy() end
            return
        end
        if click and not st.popup and minHover then ui.setVisible(false); click=false end
        if click and not st.popup and hit(x+8*s,y+8*s,w-100*s,45*s) then st.drag={kind="window",dx=st.mx-x,dy=st.my-y} end
        line(f,"header:divider",x+17*s,y+59*s,x+w-17*s,y+59*s,c.white,.07,115)
        line(f,"sidebar:divider",x+side,y+79*s,x+side,y+h-47*s,c.white,.07,115)
        local navTop,navH=y+78*s,h-127*s
        local navBottom=navTop+navH
        local navGroups,navTotal={},0
        for _,group in ipairs(groupOrder) do
            local children={}; for _,page in ipairs(pages) do if page.group==group then children[#children+1]=page end end
            if #children>0 then
                local expansion=animate("nav:groupExpansion:"..group,st.group==group and 1 or 0,23,st.group==group and 1 or 0)
                navGroups[#navGroups+1]={name=group,children=children,expansion=expansion}
                navTotal=navTotal+31*s+#children*33*s*expansion
            end
        end
        st.navMax=max(0,navTotal-navH)
        st.navTarget=clamp(st.navTarget,0,st.navMax)
        st.navScroll=scrollToward(clamp(st.navScroll,0,st.navMax),st.navTarget)
        local navX,navYPhysical=point(x+14*s,navTop)
        st.regions.sidebar={x=navX,y=navYPhysical,w=dimension(side-28*s),h=dimension(navH),max=st.navMax,current=st.navScroll,target=st.navTarget,scale=s*drawScale}
        local navY=navTop-st.navScroll; local index=0
        for _,groupInfo in ipairs(navGroups) do
            local group,children,expansion=groupInfo.name,groupInfo.children,groupInfo.expansion
            if #children>0 then
                index=index+1; local gy=navY; navY=navY+31*s
                if gy>=navTop-.01 and gy+29*s<=navBottom then
                local groupHover=input and hit(x+14*s,gy,side-28*s,29*s)
                local ga=animate("nav:groupHover:"..group,groupHover and 1 or 0,22,0)
                if ga>.001 then rect(f,"nav:groupHover:"..index,x+14*s,gy,side-28*s,29*s,c.white,.065*ga,7*s,116) end
                text(f,"nav:group:"..index,group,x+24*s,gy+7*s,theme.FontSize*s,c.text,st.group==group and .88 or .61,120,side-60*s,true)
                local ax,ay=x+side-27*s,gy+15*s
                line(f,"nav:groupDash:"..index,ax-4*s,ay,ax+4*s,ay,c.text,.62,120)
                if st.group~=group then line(f,"nav:groupPlus:"..index,ax,ay-4*s,ax,ay+4*s,c.text,.62,120) end
                if click and not st.popup and hit(x+14*s,gy,side-28*s,29*s) then st.group=st.group==group and "" or group end
                end
                if expansion>.001 then for _,page in ipairs(children) do
                    local py=navY; navY=navY+33*s*expansion; index=index+1
                    if expansion>.70 and py>=navTop-.01 and py+30*s<navBottom then
                        scopeOpacity=expansion; scopeDY=(1-expansion)*3*s
                        local over=input and st.group==group and expansion>.92 and hit(x+14*s,py,side-28*s,30*s); local selected=st.active==page
                        local hover=animate("nav:pageHover:"..page.title,over and 1 or 0,23,0)
                        local selection=animate("nav:pageSelected:"..page.title,selected and 1 or 0,23,selected and 1 or 0)
                        if selection>.001 or hover>.001 then rect(f,"nav:selected:"..index,x+14*s,py,side-28*s,30*s,mix(c.white,c.accent,selection),.16*selection+.065*hover,8*s,116) end
                        if selected then rect(f,"nav:marker:"..index,x+15*s,py+8*s,2*s,14*s,c.accent,.85,1*s,119) end
                        circle(f,"nav:icon:"..index,x+31*s,py+15*s,3*s,selected and c.accent or c.muted,selected and .9 or .43,120,not selected)
                        text(f,"nav:text:"..index,page.title,x+44*s,py+8*s,theme.FontSize*s,c.text,.66+.30*selection+.13*hover,121,side-67*s)
                        if click and over and not st.popup then
                            if st.active~=page then st.pageFade=theme.ReducedMotion and 1 or 0 end
                            st.active=page; st.popup=nil; st.edit=nil; st.capture=nil; st.drag=nil; st.regions.page=nil
                        end
                        scopeOpacity,scopeDY=1,0
                    end
                end end
            end
        end
        if st.navMax>0 then
            local sx,sy,sh=x+side-8*s,navTop+6*s,navH-12*s
            local th=max(24*s,sh*navH/navTotal); local ty=sy+(sh-th)*st.navScroll/st.navMax
            rect(f,"nav:scrollTrack",sx,sy,2*s,sh,c.white,.04,s,120)
            rect(f,"nav:scrollThumb",sx-s,ty,4*s,th,c.white,.23,2*s,122)
            if click and not st.popup and hit(sx-8*s,sy,16*s,sh) then
                st.drag={kind="navscroll",y=sy+th/2,h=sh-th,maximum=st.navMax}
                st.navTarget=clamp((st.my-st.drag.y)/st.drag.h,0,1)*st.navMax; st.navScroll=st.navTarget
            end
        end
        local page=st.active; local bx,by,bw,bh=x+side+22*s,y+125*s,w-side-44*s,h-171*s
        if page then
            scopeOpacity=st.pageFade; scopeDY=(1-st.pageFade)*4*s
            text(f,"content:title",page.title,bx+2*s,y+79*s,(theme.FontSize+7)*s,c.text,.96,121,bw-90*s,true)
            local count=0; local total=22*s
            for _,row in ipairs(page.rows) do if not row.hidden then total=total+rowHeight(row,s)+theme.Spacing*s; if row.kind~="Heading" and row.kind~="Label" then count=count+1 end end end
            text(f,"content:subtitle",page.interface and (page.title=="Background" and "Atmosphere and motion" or "Your interface, your preferences") or tostring(count).." controls",bx+2*s,y+106*s,12*s,c.text,.55,121,bw-10*s)
            scopeOpacity,scopeDY=1,0
            rect(f,"content:body",bx,by,bw,bh,mix(c.tint,c.black,.23),animate("glass:bodyOpacityAnimation",theme.BodyOpacity,24,theme.BodyOpacity),10*s,111)
            rect(f,"content:edge",bx,by,bw,bh,c.white,.09+theme.Bevel*.16,12*s,114,true)
            line(f,"content:reflection",bx+12*s,by+s,bx+bw-12*s,by+s,c.white,theme.Specular*.19,115)
            local maxScroll=max(0,total-bh)
            page.targetScroll=clamp(page.targetScroll or 0,0,maxScroll)
            if input and not st.edit and not st.capture and not st.popup then
                if hit(x+14*s,navTop,side-28*s,navH) then
                    if key(34) then st.navTarget=min(st.navMax,st.navTarget+dt*430*s) end
                    if key(33) then st.navTarget=max(0,st.navTarget-dt*430*s) end
                    st.regions.sidebar.target=st.navTarget
                else
                    if key(34) then page.targetScroll=min(maxScroll,page.targetScroll+dt*430*s) end
                    if key(33) then page.targetScroll=max(0,page.targetScroll-dt*430*s) end
                end
            end
            page.scroll=scrollToward(clamp(page.scroll,0,maxScroll),page.targetScroll)
            local pageX,pageY=point(bx,by)
            st.regions.page={x=pageX,y=pageY,w=dimension(bw),h=dimension(bh),max=maxScroll,current=page.scroll,target=page.targetScroll,scale=s*drawScale,page=page}
            local ry=by+10*s-page.scroll
            scopeOpacity=st.pageFade; scopeDY=(1-st.pageFade)*4*s
            for _,row in ipairs(page.rows) do if not row.hidden then
                local rh=rowHeight(row,s)
                                                                                               
                if ry>=by+4*s and ry+rh<=by+bh-4*s then
                    drawRow(f,row,bx+5*s,ry,bw-20*s,s,c,click,input,y+h-43*s)
                    if not st.alive then return end
                else row.bounds=nil end
                ry=ry+rh+theme.Spacing*s
            else row.bounds=nil end end
            if maxScroll>0 then
                local sx,sy,sh=bx+bw-8*s,by+12*s,bh-24*s; local th=max(25*s,sh*bh/total); local ty=sy+(sh-th)*page.scroll/maxScroll
                rect(f,"scroll:track",sx,sy,2*s,sh,c.white,.045,s,120); rect(f,"scroll:thumb",sx-s,ty,4*s,th,c.white,.25,2*s,122)
                if click and not st.popup and hit(sx-8*s,sy,16*s,sh) then
                    st.drag={kind="scroll",y=sy+th/2,h=sh-th,maximum=maxScroll}
                    page.targetScroll=clamp((st.my-st.drag.y)/st.drag.h,0,1)*maxScroll; page.scroll=page.targetScroll
                end
            end
            drawPopup(f,c,s,click,input)
            scopeOpacity,scopeDY=1,0
        end
        local contextualHint=st.edit and "Enter to apply  /  Esc to cancel" or st.capture and "Press a key  /  Esc to cancel" or st.tip
        if contextualHint then text(f,"footer:hint",contextualHint,x+side+24*s,y+h-27*s,10*s,c.text,.39,121,w-side-65*s) end
        text(f,"footer:private","PRIVATE",x+24*s,y+h-27*s,10*s,c.text,.3,120,side-40*s)
        line(f,"resize:A",x+w-21*s,y+h-9*s,x+w-9*s,y+h-21*s,c.white,.24,124)
        line(f,"resize:B",x+w-15*s,y+h-9*s,x+w-9*s,y+h-15*s,c.white,.18,124)
        if click and not st.popup and hit(x+w-27*s,y+h-27*s,24*s,24*s) then st.drag={kind="resize",dx=x+w-st.mx,dy=y+h-st.my} end
        finish(f)
    end
    local tab=ui.AddTab("Interface")
    local appearance=tab:Section("Appearance",{Group="Settings",Interface=true})
    local background=tab:Section("Background",{Group="Settings",Interface=true})
    local settings=tab:Section("Interface settings",{Group="Settings",Interface=true})
    ui.profileSection=settings; ui.SettingsSection=settings; ui.BackgroundSection=background
    local function bind(name,row)
        settingRows[name]=row
        row.callback=function(value,alpha)
            theme[name]=row.kind=="Color" and colorValues(value,alpha) or value
            safe(ctx.onAppearanceChanged,ui.exportAppearance())
        end
        return row
    end
    appearance:Heading("Glass")
    bind("Opacity",appearance:SliderFloat("thalassar_opacity","Window opacity",.35,1,theme.Opacity,"%.2f"))
    bind("BodyOpacity",appearance:SliderFloat("thalassar_body_opacity","Content opacity",.05,.95,theme.BodyOpacity,"%.2f"))
    bind("Rounding",appearance:SliderInt("thalassar_rounding","Corner radius",0,28,theme.Rounding))
    bind("Specular",appearance:SliderFloat("thalassar_specular","Glass reflection",0,1,theme.Specular,"%.2f"))
    bind("Bevel",appearance:SliderFloat("thalassar_bevel","Glass edge depth",0,1,theme.Bevel,"%.2f"))
    appearance:Heading("Palette")
    local palettes={{tint={29,32,35,255},accent={147,171,182,255},text={237,239,240,255}},
        {tint={35,33,31,255},accent={176,165,144,255},text={242,239,232,255}},
        {tint={27,33,38,255},accent={149,176,180,255},text={236,241,242,255}},
        {tint={48,48,47,255},accent={178,183,172,255},text={243,244,240,255}}}
    appearance:Combo("thalassar_palette","Preset",{"Graphite","Warm charcoal","Deep slate","Soft stone"},0,function(index)
        local p=palettes[index+1]; for _,name in ipairs({"Tint","Accent","Text"}) do set(settingRows[name],true,p[string.lower(name)]) end
    end)
    bind("Tint",appearance:ColorPicker("thalassar_tint",29,32,35,255,nil,"Glass tint"))
    bind("Accent",appearance:ColorPicker("thalassar_accent",147,171,182,255,nil,"Accent"))
    bind("Text",appearance:ColorPicker("thalassar_text",237,239,240,255,nil,"Text color"))
    appearance:Heading("Typography and layout")
    bind("Scale",appearance:SliderFloat("thalassar_scale","Interface scale",.75,1.5,theme.Scale,"%.2f"))
    bind("FontSize",appearance:SliderInt("thalassar_font_size","Text size",11,18,theme.FontSize))
    bind("Spacing",appearance:SliderInt("thalassar_spacing","Control spacing",0,12,theme.Spacing))
    local fontCodes={1,0,11,5}
    local fontRow=appearance:Combo("thalassar_font","Font",{"System","Clean UI","Soft bold","Monospace"},0,function(index) theme.Font=fontCodes[index+1]; safe(ctx.onAppearanceChanged,ui.exportAppearance()) end)
    settingRows.Font={kind="FontSetting",callback=function(value)
        local index=0; for i,v in ipairs(fontCodes) do if v==value then index=i-1 end end; set(fontRow,true,index)
    end}
    background:Heading("Surface")
    bind("Grain",background:Toggle("thalassar_grain","Fine glass grain",theme.Grain))
    bind("GrainStrength",background:SliderFloat("thalassar_grain_strength","Grain intensity",0,.5,theme.GrainStrength,"%.2f"))
    bind("Glow",background:Toggle("thalassar_glow","Soft edge glow",theme.Glow))
    bind("GlowStrength",background:SliderFloat("thalassar_glow_strength","Glow intensity",0,1,theme.GlowStrength,"%.2f"))
    bind("Vignette",background:Toggle("thalassar_vignette","Inner edge shade",theme.Vignette))
    bind("VignetteStrength",background:SliderFloat("thalassar_vignette_strength","Shade intensity",0,.4,theme.VignetteStrength,"%.2f"))
    background:Heading("Motion")
    bind("Particles",background:Toggle("thalassar_particles","Drifting light specks",theme.Particles))
    bind("ParticleAmount",background:SliderInt("thalassar_particles_amount","Speck amount",1,24,theme.ParticleAmount))
    bind("ParticleSpeed",background:SliderFloat("thalassar_particles_speed","Drift speed",0,1,theme.ParticleSpeed,"%.2f"))
    bind("ReducedMotion",background:Toggle("thalassar_reduced_motion","Reduced motion",theme.ReducedMotion))
    bind("AnimationSpeed",background:SliderFloat("thalassar_animation_speed","Interaction speed",.5,2,theme.AnimationSpeed,"%.2f"))
    settings:Heading("Window")
    bind("MenuKey",settings:Keybind("thalassar_menu_key","Show / hide shortcut",theme.MenuKey))
    settings:Button("thalassar_reset_appearance","Restore interface defaults",ui.resetAppearance)
    settings:Label("thalassar_scroll_hint","Mouse wheel scrolls the hovered panel.")
    settings:Label("thalassar_close_hint","The dash minimizes. X unloads the complete script.")
    if ctx.appearance then ui.importAppearance(ctx.appearance) end
    safe(ctx.onVisibility,st.open)
    return ui
end
return createThalassarUI

end)()
assert(type(createGlass) == "function", "Thalassar UI factory missing")
local createEffects = (function()
                                                                                 
                                                                              
local function createThalassarBackgroundEffects()
    local min, max, floor, abs = math.min, math.max, math.floor, math.abs
    local sin, sqrt, exp, pi = math.sin, math.sqrt, math.exp, math.pi
    local function clamp(v,lo,hi) return min(max(v,lo),hi) end
    local function number(v,fallback,lo,hi)
        v=tonumber(v)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return clamp(v,lo,hi)
    end
    local modes={"None","Rain","Snow","Fireflies","Bubbles","Ripples"}
    local defaults={Effect=2,Intensity=.32,Speed=.35,Wind=.12,Opacity=.56,Color={236,240,243,255}}
    local settings={Effect=2,Intensity=.32,Speed=.35,Wind=.12,Opacity=.56,Color={236,240,243,255}}
    local controls, elapsed, windOffset, activeMode, envelope = {}, 0, 0, settings.Effect, 1
    local module={}

                                                                                           
    local seed,particles=19071995,{}
    local function random()
        seed=(seed*48271)%2147483647
        return seed/2147483647
    end
    for i=1,64 do
        particles[i]={x=random(),y=random(),size=random(),speed=random(),phase=random()*2*pi,depth=random()}
    end

    local function colorBytes(value,alpha)
        local r,g,b,a
        if type(value)=="table" or type(value)=="userdata" then
            local ok,red,green,blue=pcall(function() return value.R,value.G,value.B end)
            if ok and type(red)=="number" then
                r,g,b=red*255,green*255,blue*255
                a=number(alpha,1,0,255); if a<=1 then a=a*255 end
            elseif type(value)=="table" then
                r,g,b,a=value[1],value[2],value[3],value[4] or alpha or 255
            end
        end
        return {number(r,236,0,255),number(g,240,0,255),number(b,243,0,255),number(a,255,0,255)}
    end
    local function effectIndex(value)
        if type(value)=="string" then
            for i,name in ipairs(modes) do if string.lower(value)==string.lower(name) then return i-1 end end
            return settings.Effect
        end
        return floor(number(value,settings.Effect,0,#modes-1)+.5)
    end
    local function sync()
        for key,row in pairs(controls) do
            if type(row.SetValue)=="function" then
                if key=="Color" then row:SetValue(settings.Color)
                else row:SetValue(settings[key]) end
            end
        end
    end

    function module.install(section)
        assert(section and type(section.Combo)=="function" and type(section.SliderFloat)=="function","Background effects need a Thalassar settings section")
        if next(controls) then return module end
        if type(section.Heading)=="function" then section:Heading("Weather and ambient effects") end
        controls.Effect=section:Combo("thalassar_bg_effect","Background effect",modes,settings.Effect,function(value)
            settings.Effect=effectIndex(value)
        end)
        controls.Intensity=section:SliderFloat("thalassar_bg_intensity","Effect intensity",0,1,settings.Intensity,"%.2f",function(value)
            settings.Intensity=number(value,settings.Intensity,0,1)
        end)
        controls.Speed=section:SliderFloat("thalassar_bg_speed","Effect speed",0,1,settings.Speed,"%.2f",function(value)
            settings.Speed=number(value,settings.Speed,0,1)
        end)
        controls.Wind=section:SliderFloat("thalassar_bg_wind","Wind",-1,1,settings.Wind,"%.2f",function(value)
            settings.Wind=number(value,settings.Wind,-1,1)
        end)
        controls.Opacity=section:SliderFloat("thalassar_bg_opacity","Effect opacity",0,1,settings.Opacity,"%.2f",function(value)
            settings.Opacity=number(value,settings.Opacity,0,1)
        end)
        if type(section.ColorPicker)=="function" then
            local c=settings.Color
            controls.Color=section:ColorPicker("thalassar_bg_color",c[1],c[2],c[3],c[4],function(color,alpha)
                settings.Color=colorBytes(color,alpha)
            end,"Effect color")
        end
        if type(section.Tip)=="function" then section:Tip("Effects stay inside the window. Reduced motion freezes their movement.") end
        return module
    end

    function module.export()
        return {Version=1,Effect=modes[settings.Effect+1],Intensity=settings.Intensity,Speed=settings.Speed,
            Wind=settings.Wind,Opacity=settings.Opacity,Color={settings.Color[1],settings.Color[2],settings.Color[3],settings.Color[4]}}
    end
    function module.import(saved)
        if type(saved)~="table" then return false end
        if saved.Effect~=nil then settings.Effect=effectIndex(saved.Effect) end
        if saved.Intensity~=nil then settings.Intensity=number(saved.Intensity,settings.Intensity,0,1) end
        if saved.Speed~=nil then settings.Speed=number(saved.Speed,settings.Speed,0,1) end
        if saved.Wind~=nil then settings.Wind=number(saved.Wind,settings.Wind,-1,1) end
        if saved.Opacity~=nil then settings.Opacity=number(saved.Opacity,settings.Opacity,0,1) end
        if saved.Color~=nil then settings.Color=colorBytes(saved.Color) end
        sync(); return true
    end
    function module.reset() return module.import(defaults) end

                                                                                           
    local function roundedDistance(x,y,b)
        local qx=abs(x-(b.x+b.w*.5))-(b.w*.5-b.r)
        local qy=abs(y-(b.y+b.h*.5))-(b.h*.5-b.r)
        local dx,dy=max(qx,0),max(qy,0)
        return sqrt(dx*dx+dy*dy)+min(max(qx,qy),0)-b.r
    end
    local function inside(x,y,b,margin) return roundedDistance(x,y,b)<=-(margin or 0)-.001 end
    local function clippedLine(x1,y1,x2,y2,b)
        local a,c=inside(x1,y1,b,.8),inside(x2,y2,b,.8)
        if not a and not c then return end
        if a and c then return x1,y1,x2,y2 end
                                                                                                 
        local ix,iy,ox,oy=x1,y1,x2,y2
        if not a then ix,iy,ox,oy=x2,y2,x1,y1 end
        local lo,hi=0,1
        for _=1,10 do
            local t=(lo+hi)*.5
            if inside(ix+(ox-ix)*t,iy+(oy-iy)*t,b,.8) then lo=t else hi=t end
        end
        local ex,ey=ix+(ox-ix)*lo,iy+(oy-iy)*lo
        if a then return ix,iy,ex,ey else return ex,ey,ix,iy end
    end
    local function wrapped(value,size) return value-floor(value/size)*size end

    function module.draw(api)
        if type(api)~="table" or type(api.circle)~="function" or type(api.line)~="function" then return 0 end
        local w,h=number(api.w,0,0,10000),number(api.h,0,0,10000)
        if w<8 or h<8 then return 0 end
        local scale=number(api.scale,1,.1,4)
        local dt=number(api.dt,1/60,0,.1)
        if not api.reducedMotion then
            local motion=dt*settings.Speed*2.4
            elapsed=elapsed+motion; windOffset=windOffset+motion*settings.Wind
        end
        if api.reducedMotion then
            activeMode=settings.Effect; envelope=activeMode==0 and 0 or 1
        else
            local target=settings.Effect==activeMode and activeMode~=0 and 1 or 0
            envelope=envelope+(target-envelope)*(1-exp(-dt*12))
            if settings.Effect~=activeMode and envelope<.02 then activeMode=settings.Effect; envelope=0 end
        end
        local opacity=number(api.opacity,1,0,1)*settings.Opacity*(settings.Color[4]/255)*envelope
        if activeMode==0 or settings.Intensity<=0 or opacity<.002 then return 0 end
        local b={x=number(api.x,0,-10000,10000),y=number(api.y,0,-10000,10000),w=w,h=h,
            r=number(api.radius,0,0,min(w,h)*.5)}
        local color
        local c=settings.Color
        local ok,result=pcall(function()
            if activeMode==3 and c[1]==236 and c[2]==240 and c[3]==243 then return Color3.fromRGB(244,232,203) end
            return Color3.fromRGB(c[1],c[2],c[3])
        end)
        if ok then color=result else color=api.colors and (api.colors.white or api.colors.accent) end
        if not color then return 0 end
        local count,shapes,t=0,0,elapsed
        local function circle(id,x,y,r,alpha,outline,z)
            if r>.05 and alpha>.002 and inside(x,y,b,r+.65) then
                api.circle("background:"..id,x,y,r,color,clamp(alpha,0,1),z or 107,outline==true)
                shapes=shapes+1
            end
        end
        if activeMode==1 then
            count=floor(64*settings.Intensity+.5)
            local velocity=150*scale
            local wind=settings.Wind*42*scale
            for i=1,count do
                local p=particles[i]
                local phase=p.y+t*velocity*(.72+p.speed*.56)/h
                local x=b.x+wrapped(p.x*w+windOffset*42*scale,w)
                local y=b.y+wrapped(phase*h,h)
                local length=(8+p.size*12)*scale
                local x1,y1,x2,y2=clippedLine(x-wind/velocity*length,y-length,x,y,b)
                if x1 then
                    api.line("background:rain:"..i,x1,y1,x2,y2,color,opacity*(.38+p.depth*.4),107)
                    shapes=shapes+1
                end
                if i<=8 then
                    local q=phase-floor(phase)
                    if q>.86 then
                        local f=(q-.86)/.14
                        circle("particle:"..i,x,b.y+h-11*scale,(2+6*f)*scale,opacity*.28*(1-f),true,108)
                    end
                end
            end
        elseif activeMode==2 then
            count=floor(64*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local drift=sin(t*.25+p.phase)*12*scale
                local x=b.x+wrapped(p.x*w+windOffset*20*scale+drift,w)
                local y=b.y+wrapped(p.y*h+t*18*(.6+p.speed*.6)*scale,h)
                circle("particle:"..i,x,y,(.7+p.size*1.35)*scale,opacity*(.36+p.depth*.55),false)
            end
        elseif activeMode==3 then
            count=floor(32*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local x=b.x+wrapped(p.x*w+windOffset*10*scale+sin(t*.17+p.phase)*17*scale,w)
                local y=b.y+wrapped(p.y*h+sin(t*.2+p.phase)*13*scale,h)
                local pulse=.35+.65*(.5+.5*sin(t*.85+p.phase))
                local radius=(.85+p.size*.8)*scale
                circle("halo:"..i,x,y,radius*(3+p.depth*2),opacity*pulse*.12,false)
                circle("particle:"..i,x,y,radius,opacity*pulse*(.6+p.depth*.3),false,108)
            end
        elseif activeMode==4 then
            count=floor(36*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local x=b.x+wrapped(p.x*w+sin(t*.22+p.phase)*13*scale+windOffset*12*scale,w)
                local y=b.y+h-wrapped(p.y*h+t*18*(.6+p.speed*.6)*scale,h)
                circle("particle:"..i,x,y,(2+p.size*7)*scale,opacity*(.22+p.depth*.35),true)
            end
        elseif activeMode==5 then
            count=floor(16*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local phase=p.y+t*.18*(.8+p.speed*.5)
                local f=phase-floor(phase)
                local x=b.x+(.1+p.x*.8)*w
                local y=b.y+(.1+p.depth*.8)*h
                circle("particle:"..i,x,y,(3+f*(24+p.size*48))*scale,opacity*.72*(1-f)^1.5,true)
            end
        end
        return shapes
    end
    return module
end
return createThalassarBackgroundEffects

end)()
local effects = createEffects()
local createWheelBridge = (function()
                                                                                     
local function createWheelBridge()
    local leasePath="Thalassar-Private.wheel-lease.txt"
    local eventPath="Thalassar-Private.wheel.txt"
    local statusPath="Thalassar-Private.wheel-status.txt"
    local ackPath="Thalassar-Private.wheel-ack.txt"
    local function monotonic() return type(tick)=="function" and tick() or os.clock() end
                                                                                   
    local timeOrigin, clockOrigin=os.time(),monotonic()
    local function now() return timeOrigin+(monotonic()-clockOrigin) end
    local session="thalassar-"..tostring(now()).."-"..tostring(math.random(100000,999999))
    local menu, closed, lastRead, nextLease, previousSequence, previousTotal
    local latestEvent,previousGeneration=0,nil
    local retiredGenerations={}
    local lastLeaseWrite,lastLeaseError=0,nil
    local lastAcknowledgement,lastAckError=nil,nil
    local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
                                                                               
                                                                                  
    local function fresh(time,stamp) return time-stamp<=1.5 and stamp-time<=2 end
    local bridge={}
    previousSequence,previousTotal,lastRead,nextLease=0,0,0,0
    function bridge.update(force)
        if closed or not menu then return end
        local time=now()
        if not force and time<nextLease then return end
        nextLease=time+.5
        local appearanceOK,appearance=pcall(menu.exportAppearance)
        local interactionOK,interacting=pcall(menu.isInteracting)
        if not appearanceOK or type(appearance)~="table" or not interactionOK then
            lastLeaseError="menu state unavailable"
            return
        end
        local window=appearance.Window
        local scale=appearance.Scale or 1
        if type(window)~="table" or not finite(scale) or scale<=0 or not finite(window[1])
            or not finite(window[2]) or not finite(window[3]) or not finite(window[4])
            or window[3]<=0 or window[4]<=0 then
            lastLeaseError="invalid menu geometry"
            return
        end
        local text=table.concat({"run",session,interacting and "1" or "0",
            tostring(window[1]),tostring(window[2]),tostring(window[3]*scale),
            tostring(window[4]*scale),tostring(time+10)},"|")
        local written,err=pcall(writefile,leasePath,text)
        if written then lastLeaseWrite,lastLeaseError=time,nil
        else lastLeaseError=tostring(err); nextLease=time+.1 end
    end
    function bridge.setUI(value) menu=value; bridge.update(true) end
    function bridge.consume()
        if closed then return 0 end
                                                                             
                                                                              
        bridge.update()
        local time=now()
        if time-lastRead<.025 then return 0 end
        lastRead=time
        local existsOK,exists=pcall(isfile,eventPath)
        if not existsOK or not exists then return 0 end
        local ok,text=pcall(readfile,eventPath)
        if not ok or type(text)~="string" then return 0 end
        local id,generation,seq,total,x,y,stamp=text:match("^2|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        if not id then id,seq,total,x,y,stamp=text:match("^1|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$") end
        if id~=session then return 0 end
        seq,total,x,y,stamp=tonumber(seq),tonumber(total),tonumber(x),tonumber(y),tonumber(stamp)
        if not finite(seq) or seq<0 or seq%1~=0 or not finite(total) or not finite(x)
            or not finite(y) or not finite(stamp) then return 0 end
                                                                               
                                                                                  
        if generation and generation~=previousGeneration then
            if retiredGenerations[generation] or stamp<latestEvent then return 0 end
            if previousGeneration then retiredGenerations[previousGeneration]=true end
            previousGeneration,previousSequence,previousTotal=generation,0,0
            latestEvent=stamp
            if not fresh(time,stamp) then
                                                                              
                                                                         
                previousSequence,previousTotal=seq,total
                return 0
            end
        end
                                                                                 
        if seq==0 and previousSequence>0 and stamp>latestEvent and fresh(time,stamp) then
            previousSequence,previousTotal,latestEvent=0,total,stamp
            return 0
        end
        if seq<=previousSequence or stamp<latestEvent then return 0 end
        local delta=total-previousTotal
        previousSequence,previousTotal,latestEvent=seq,total,stamp
        if not fresh(time,stamp) then return 0 end
        return math.clamp(delta,-32,32),x,y
    end
    function bridge.acknowledge(handled,region,delta,x,y)
        if closed or previousSequence<=0 or not finite(delta) or delta==0 then return false end
        local scope=type(region)=="string" and region or "none"
        local bounds=type(region)=="table" and region or nil
        if bounds then scope=type(bounds.scope)=="string" and bounds.scope or "none" end
        if not bounds and menu and type(menu.scrollRegions)=="function" then
            local regionsOK,regions=pcall(menu.scrollRegions)
            if regionsOK and type(regions)=="table" then bounds=regions[scope] end
        end
        scope=scope:gsub("|","")
        local target=type(bounds)=="table" and bounds.target or nil
        local current=type(bounds)=="table" and bounds.current or nil
        local maximum=type(bounds)=="table" and bounds.max or nil
        local function number(value) return finite(value) and tostring(value) or "none" end
        local stamp=now()
        local text=table.concat({"1",session,previousGeneration or "legacy",tostring(previousSequence),
            scope,handled and "1" or "0",number(target),number(current),number(maximum),
            number(delta),number(x),number(y),tostring(stamp)},"|")
        local written,err=pcall(writefile,ackPath,text)
        lastAckError=not written and tostring(err) or nil
        if written then
            lastAcknowledgement={sequence=previousSequence,generation=previousGeneration,scope=scope,
                handled=handled==true,target=target,current=current,max=maximum,delta=delta,x=x,y=y,time=stamp}
        end
        return written
    end
    function bridge.status()
        local companionState,companionSession,companionPid,heartbeat
        local readOK,text=pcall(readfile,statusPath)
        if readOK and type(text)=="string" then
            companionState,companionSession,companionPid,heartbeat=text:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|")
            heartbeat=tonumber(heartbeat)
        end
        local time=now()
        local interactionOK,interacting=false,false
        if menu and not closed then interactionOK,interacting=pcall(menu.isInteracting) end
        local alive=finite(heartbeat) and time-heartbeat<=4 and heartbeat-time<=2
        local ready=alive and companionState=="ready" and companionSession==session
            and interactionOK and interacting and time-lastLeaseWrite<=2 and not closed
        return {session=session,sequence=previousSequence,total=previousTotal,
            latestEvent=latestEvent,generation=previousGeneration,closed=closed==true,source="automatic local companion",
            lastLeaseWrite=lastLeaseWrite,lastLeaseError=lastLeaseError,companionState=companionState or "unavailable",
            companionPid=tonumber(companionPid),companionHeartbeat=heartbeat,companionAlive=alive==true,ready=ready==true,
            acknowledgementPath=ackPath,lastAcknowledgement=lastAcknowledgement,lastAckError=lastAckError}
    end
    function bridge.close()
        if closed then return end
        closed=true
        pcall(writefile,leasePath,"stop|"..session)
    end
    return bridge
end
return createWheelBridge

end)()
local wheelBridge = createWheelBridge()
local glass = createGlass({
    title = "Thalassar Private",
    visible = false,
    appearance = previousAppearance,
    reportError = uiError,
    onError = function(message) uiError("glass UI", message) end,
    onClose = function() if controller then controller.stop() end end,
    drawBackgroundEffects = effects.draw,
    consumeWheel = wheelBridge.consume,
    onWheelConsumed = wheelBridge.acknowledge,
    onVisibility = function(open)
        if type(setrobloxinput)=="function" then pcall(setrobloxinput, not open) end
        wheelBridge.update(true)
    end,
    profileStatus = function() return lastProfileResult end,
})
wheelBridge.setUI(glass)
local createCrosshairs=(function()
                                                                                           
                                                                                   
local function createThalassarCrosshairs(ctx)
    ctx=ctx or {}
    local ui,config=ctx.ui,ctx.config or {}
    local min,max,floor,sin,cos,pi=math.min,math.max,math.floor,math.sin,math.cos,math.pi
    local styles={"Star of David","Cat","Plus","Dot","Circle","Scope","T","Chevron","Hollow circle","X"}
    local defaults={Gap=3,Thickness=1.5,Outline=true,OutlineThickness=1,CenterDot=false,
        Rotation=0,Opacity=1,Position=0,OutlineColor={8,10,11,220}}
    local settings={}
    for key,value in pairs(defaults) do settings[key]=type(value)=="table" and {value[1],value[2],value[3],value[4]} or value end
    local objects,frame,controls={}, {}, {}
    local state={alive=true,count=0,visible=0,style=nil,time=0,error=nil}
    local mouse=ctx.mouse
    if not mouse then pcall(function() mouse=game:GetService("Players").LocalPlayer:GetMouse() end) end
    local module={styles=styles}
    local function clamp(v,lo,hi) return min(max(v,lo),hi) end
    local function number(v,fallback,lo,hi)
        v=tonumber(v)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return clamp(v,lo,hi)
    end
    local function colorBytes(value,alpha)
        local r,g,b,a
        if type(value)=="table" or type(value)=="userdata" then
            local ok,red,green,blue=pcall(function() return value.R,value.G,value.B end)
            if ok and type(red)=="number" then
                r,g,b=red*255,green*255,blue*255
                a=number(alpha,1,0,255); if a<=1 then a=a*255 end
            elseif type(value)=="table" then r,g,b,a=value[1],value[2],value[3],value[4] or alpha or 255 end
        end
        return {number(r,8,0,255),number(g,10,0,255),number(b,11,0,255),number(a,220,0,255)}
    end
    local function drawing(id,kind)
        local d=objects[id]
        if not d then
            d=Drawing.new(kind); assert(d,"Unable to create crosshair "..kind)
            objects[id]=d; state.count+=1; d.Visible=false; d.ZIndex=70
        end
        frame[id]=true
        return d
    end
    local function hide()
        for _,d in pairs(objects) do d.Visible=false end
        state.visible=0
    end
    local function getCenter()
        local x,y
        if settings.Position==0 and mouse then
            pcall(function() x,y=mouse.X,mouse.Y end)
            if type(x)=="number" and type(y)=="number" and x==x and y==y then return x,y end
        end
        if ctx.viewport then
            local ok,a,b=pcall(ctx.viewport)
            if ok and type(a)=="number" and type(b)=="number" then return a*.5,b*.5 end
            if ok and a then return a.X*.5,a.Y*.5 end
        end
        local ok,v=pcall(function() return workspace.CurrentCamera.ViewportSize end)
        if ok and v then return v.X*.5,v.Y*.5 end
        return 960,540
    end
    local function getColor()
        if ui and type(ui.GetValue)=="function" then
            local ok,r,g,b,a=pcall(ui.GetValue,"mtc_star_color")
            if ok and type(r)=="number" then
                return Color3.fromRGB(number(r,35,0,255),number(g,105,0,255),number(b,255,0,255)),number(a,255,0,255)/255
            end
            if ok and (type(r)=="table" or type(r)=="userdata") then
                local values=colorBytes(r,g)
                return Color3.fromRGB(values[1],values[2],values[3]),values[4]/255
            end
        end
        return Color3.fromRGB(35,105,255),1
    end
    local function sync()
        for key,row in pairs(controls) do if type(row.SetValue)=="function" then row:SetValue(settings[key]) end end
    end
    function module.bindController(value) assert(type(value)=="table","Crosshairs need the controller config"); config=value; return module end
    function module.install(section)
        assert(section and type(section.SliderFloat)=="function","Crosshairs need a Thalassar section")
        if next(controls) then return module end
        section:Heading("Shape and placement")
        controls.Position=section:Combo("thalassar_crosshair_position","Position",{"Mouse","Screen center"},settings.Position,function(v) settings.Position=floor(number(v,0,0,1)) end)
        controls.Gap=section:SliderInt("thalassar_crosshair_gap","Center gap",0,20,settings.Gap,function(v) settings.Gap=number(v,3,0,20) end)
        controls.Thickness=section:SliderFloat("thalassar_crosshair_thickness","Line thickness",.5,6,settings.Thickness,"%.2f",function(v) settings.Thickness=number(v,1.5,.5,6) end)
        controls.CenterDot=section:Toggle("thalassar_crosshair_dot","Center dot",settings.CenterDot,function(v) settings.CenterDot=v==true end)
        controls.Rotation=section:SliderInt("thalassar_crosshair_rotation","Rotation",-180,180,settings.Rotation,function(v) settings.Rotation=number(v,0,-180,180) end)
        controls.Opacity=section:SliderFloat("thalassar_crosshair_opacity","Opacity",0,1,settings.Opacity,"%.2f",function(v) settings.Opacity=number(v,1,0,1) end)
        section:Heading("Outline")
        controls.Outline=section:Toggle("thalassar_crosshair_outline","Outline",settings.Outline,function(v) settings.Outline=v==true end)
        controls.OutlineThickness=section:SliderFloat("thalassar_crosshair_outline_thickness","Outline thickness",.5,3,settings.OutlineThickness,"%.2f",function(v) settings.OutlineThickness=number(v,1,.5,3) end)
        local c=settings.OutlineColor
        controls.OutlineColor=section:ColorPicker("thalassar_crosshair_outline_color",c[1],c[2],c[3],c[4],function(color,alpha) settings.OutlineColor=colorBytes(color,alpha) end,"Outline color")
        section:Tip("Applies to Plus, Dot, Circle, Scope, T, Chevron, Hollow circle and X. Cursor style, color and size are in Crosshair.")
        return module
    end
    function module.export()
        local out={Version=1}
        for key,value in pairs(settings) do out[key]=type(value)=="table" and {value[1],value[2],value[3],value[4]} or value end
        return out
    end
    function module.import(saved)
        if type(saved)~="table" then return false end
        for key,ranges in pairs({Gap={0,20},Thickness={.5,6},OutlineThickness={.5,3},Rotation={-180,180},Opacity={0,1},Position={0,1}}) do
            if saved[key]~=nil then settings[key]=number(saved[key],settings[key],ranges[1],ranges[2]) end
        end
        settings.Position=floor(settings.Position)
        for _,key in ipairs({"Outline","CenterDot"}) do if type(saved[key])=="boolean" then settings[key]=saved[key] end end
        if saved.OutlineColor~=nil then settings.OutlineColor=colorBytes(saved.OutlineColor) end
        sync(); return true
    end
    function module.reset() return module.import(defaults) end
    local function render(dt)
        state.time+=number(dt,0,0,.25)
        local style=floor(number(config.CursorStyle,0,0,#styles-1))
        state.style=styles[style+1]
        if config.CustomCursor~=true or style<2 then hide(); return end
        frame={}
        local cx,cy=getCenter()
        local size=number(config.CursorSize,11,1,100)
        local gap=min(settings.Gap,max(0,size-1))
        local color,alpha=getColor()
        local reduced=false
        if ctx.reducedMotion then local ok,v=pcall(ctx.reducedMotion); reduced=ok and v==true end
        if config.CursorRainbow and not reduced then color=Color3.fromHSV((state.time*.2)%1,1,1) end
        alpha*=settings.Opacity
        local outline=settings.OutlineColor
        local outlineColor=Color3.fromRGB(outline[1],outline[2],outline[3])
        local outlineAlpha=outline[4]/255*alpha
        local angle=settings.Rotation*pi/180
        local ca,sa=cos(angle),sin(angle)
        local function point(x,y) return Vector2.new(cx+x*ca-y*sa,cy+x*sa+y*ca) end
        local function stroke(id,x1,y1,x2,y2)
            if settings.Outline then
                local d=drawing(id..":outline","Line")
                d.From=point(x1,y1); d.To=point(x2,y2); d.Thickness=settings.Thickness+settings.OutlineThickness*2
                d.Color=outlineColor; d.Transparency=outlineAlpha; d.ZIndex=69; d.Visible=outlineAlpha>0
            end
            local d=drawing(id,"Line")
            d.From=point(x1,y1); d.To=point(x2,y2); d.Thickness=settings.Thickness
            d.Color=color; d.Transparency=alpha; d.ZIndex=70; d.Visible=alpha>0
        end
        local function ring(id,r,filled)
            if settings.Outline then
                local d=drawing(id..":outline","Circle")
                d.Position=Vector2.new(cx,cy); d.Radius=filled and r+settings.OutlineThickness or r
                d.Filled=filled; d.NumSides=64; d.Thickness=settings.Thickness+settings.OutlineThickness*2
                d.Color=outlineColor; d.Transparency=outlineAlpha; d.ZIndex=69; d.Visible=outlineAlpha>0
            end
            local d=drawing(id,"Circle")
            d.Position=Vector2.new(cx,cy); d.Radius=r; d.Filled=filled; d.NumSides=64; d.Thickness=settings.Thickness
            d.Color=color; d.Transparency=alpha; d.ZIndex=70; d.Visible=alpha>0
        end
        if style==2 then
            stroke("left",-size,0,-gap,0); stroke("right",gap,0,size,0)
            stroke("top",0,-size,0,-gap); stroke("bottom",0,gap,0,size)
        elseif style==3 then ring("dot",max(1,size*.16),true)
        elseif style==4 or style==8 then ring("ring",size,false)
        elseif style==5 then
            ring("ring",size*.68,false)
            stroke("left",-size,0,-size*.35,0); stroke("right",size*.35,0,size,0)
            stroke("top",0,-size,0,-size*.35); stroke("bottom",0,size*.35,0,size)
        elseif style==6 then
            stroke("left",-size,0,-gap,0); stroke("right",gap,0,size,0); stroke("bottom",0,gap,0,size)
        elseif style==7 then
            stroke("left",-size,size*.6,0,0); stroke("right",0,0,size,size*.6)
        elseif style==9 then
            local diagonal=size/math.sqrt(2); local inner=gap/math.sqrt(2)
            stroke("left",-diagonal,-diagonal,-inner,-inner); stroke("right",inner,inner,diagonal,diagonal)
            stroke("top",diagonal,-diagonal,inner,-inner); stroke("bottom",-inner,inner,-diagonal,diagonal)
        end
        if style~=3 and (settings.CenterDot or style==4) then ring("dot",max(1,settings.Thickness*.75),true) end
        local visible=0
        for id,d in pairs(objects) do if not frame[id] then d.Visible=false end; if d.Visible then visible+=1 end end
        state.visible=visible
    end
    function module.step(dt)
        if not state.alive then return false end
        local ok,err=pcall(render,dt)
        if not ok then state.error=tostring(err); hide(); if ctx.onError then pcall(ctx.onError,state.error) end end
        return ok
    end
    function module.status() return {alive=state.alive,drawings=state.count,visible=state.visible,style=state.style,error=state.error} end
    function module.stop()
        if not state.alive then return end
        state.alive=false
        for _,d in pairs(objects) do pcall(function() d:Remove() end) end
        objects={}; frame={}; state.visible=0
    end
    return module
end
return createThalassarCrosshairs

end)()
local crosshairs=createCrosshairs({ui=glass,reducedMotion=function() return glass.GetValue("thalassar_reduced_motion")==true end,
    onError=function(message) uiError("crosshairs",message) end})
local createWorldVisuals=(function()
                                                                                        
local function createThalassarWorldVisuals(ctx)
    ctx=ctx or {}
    local ws=ctx.workspace or game:GetService("Workspace")
    local rs=ctx.storage or game:GetService("ReplicatedStorage")
    local lighting=ctx.lighting or game:GetService("Lighting")
    local place,job=game.PlaceId,game.JobId
    local now=ctx.clock or os.clock
    local settings={Trees=false,Bushes=false,Grass=false,TerrainGrass=false,NoFog=false,FullBright=false,NoPostFX=false}
    local controls,module={},{}
    local records,order,properties={}, {}, {}
    local roots,stack,seen={}, {}, {}
    local running,nextDiscovery,nextLighting,lastStep=true,0,0,0
    local scans,hidden,restored,failures,visited=0,0,0,0,0
    local nextRecord=1
                                                                            
                                                                                
    local foliageNames={myrtus=true}
    local terrainStatus="Terrain decoration is not exposed by this Matcha build"
    local lightStatus="Full bright is not exposed by this Matcha build"
    local terrain=ws:FindFirstChild("Terrain")
    local capabilities={TerrainGrass=terrain and type(terrain.Decoration)=="boolean" or false,
        FullBright=type(lighting.Brightness)=="number" and type(lighting.ClockTime)=="number"
            and lighting.Ambient~=nil,LegacyFog=type(lighting.FogEnd)=="number"}
    local function same(a,b) return a and b and a.Address==b.Address end
    local function session() return running and game.PlaceId==place and game.JobId==job end
    local function classPart(c) return c=="Part" or c=="MeshPart" or c=="UnionOperation" or c=="WedgePart" end
    local function compact(n) return tostring(n or ""):lower():gsub("[%s_%-]","") end
    local function safeChildren(node)
        local ok,list=pcall(function() return node:GetChildren() end)
        return ok and type(list)=="table" and list or {}
    end
    local function protected(node)
        local name=compact(node.Name)
        return name=="propcollision" or name=="collisionproxy" or node.ClassName=="Humanoid"
            or name=="spawnedvehicles" or name=="spawnedplayers" or name=="placedbuildings"
    end
    local kinds={trees="Trees",tree="Trees",bush="Bushes",bushes="Bushes",groundfoliage="Grass",preciserenderfoliage="Grass",grass="Grass"}
    local function knownKind(node)
        local n=compact(node.Name)
        if kinds[n] then return kinds[n] end
        if n:match("^pine%d*$") or n:match("^regtree%d*$") or n:match("^sometree%d*$")
            or n:match("^oaktree%d*$") or n:match("^talltree%d*$") or n:match("^appletree%d*$")
            or n:match("^tree%d*$") then return "Trees" end
        if n:match("^bush%d*$") or n=="deadbush" then return "Bushes" end
        if n=="tallgrassperf" or n=="tallgrassprec" or n=="shortgrass" or n=="browngrass" or n=="yellowgrass" or n=="tallgrass" then return "Grass" end
        return nil
    end
    local function writeParent(node,parent)
        local ok=pcall(function() node.Parent=parent end)
        if ok and same(node.Parent,parent) then return true end
        failures+=1;return false
    end
    local function hide(node,kind)
        if not session() or not node or not node.Address or not node.Parent or same(node.Parent,rs) then return false end
        local id=node.Address;local record=records[id]
        if record and not same(node.Parent,record.parent) then
                                                                                          
            record.parent=node.Parent
        end
        if not record then
            record={node=node,address=id,class=node.ClassName,parent=node.Parent,kind=kind}
            records[id]=record;order[#order+1]=id
        end
        if writeParent(node,rs) then hidden+=1;record.owned=true;return true end
        return false
    end
    local function restoreRecord(id,force)
        local r=records[id];if not r then return true end
        if not force and settings[r.kind] then return false end
        if r.node.Address~=r.address or r.node.ClassName~=r.class then records[id]=nil;return true end
        if same(r.node.Parent,rs) and r.parent and r.parent.Address then
            if not writeParent(r.node,r.parent) then return false end
            restored+=1
        end
        records[id]=nil;return true
    end
    local function property(node,key,value,kind)
        local ok,current=pcall(function() return node[key] end)
        if not ok or type(current)~=type(value) then return false end
        local id=tostring(node.Address)..":"..key;local r=properties[id]
        if not r then r={node=node,key=key,original=current,kind=kind};properties[id]=r end
        if current~=value then
            local written=pcall(function() node[key]=value end)
            if not written or node[key]~=value then failures+=1;return false end
        end
        r.written=value;return true
    end
    local function restoreProperties(force)
        for id,r in pairs(properties) do if force or not settings[r.kind] then
            if r.node[r.key]==r.written then
                local ok=pcall(function() r.node[r.key]=r.original end)
                if not ok or r.node[r.key]~=r.original then failures+=1;continue end
            end
            properties[id]=nil
        end end
    end
    local function updateLighting()
        restoreProperties(false)
        if settings.TerrainGrass then
            local terrain=ws:FindFirstChild("Terrain")
            terrainStatus=terrain and property(terrain,"Decoration",false,"TerrainGrass") and "Terrain grass disabled" or "Terrain decoration is unavailable in this Matcha build"
        else terrainStatus=capabilities.TerrainGrass and "Off" or "Unsupported by current Matcha bindings" end
        if settings.NoFog and capabilities.LegacyFog then
            property(lighting,"FogStart",1e6,"NoFog");property(lighting,"FogEnd",1e6+1,"NoFog")
        end
        if settings.FullBright then
            local brightness=property(lighting,"Brightness",2,"FullBright")
            local clock=property(lighting,"ClockTime",14,"FullBright")
            local ambient=property(lighting,"Ambient",Color3.fromRGB(178,178,178),"FullBright")
            property(lighting,"OutdoorAmbient",Color3.fromRGB(178,178,178),"FullBright")
            lightStatus=brightness and clock and ambient and "Full bright applied" or "Full bright lighting fields unavailable in this Matcha build"
        else lightStatus=capabilities.FullBright and "Off" or "Unsupported by current Matcha bindings" end
        for _,node in ipairs(safeChildren(lighting)) do
            if settings.NoFog and node.ClassName=="Atmosphere" then hide(node,"NoFog") end
            if settings.NoPostFX and (node.ClassName=="BloomEffect" or node.ClassName=="SunRaysEffect" or node.ClassName=="ColorCorrectionEffect" or node.ClassName=="DepthOfFieldEffect") then hide(node,"NoPostFX") end
        end
    end
    local function addRoot(node,kind)
        if not node or not node.Address then return end
        roots[node.Address]=node;stack[#stack+1]={node=node,kind=kind}
    end
    local function discover()
        stack={};seen={};roots={};scans+=1
        local map=ws:FindFirstChild("Map")
        local parts=map and map:FindFirstChild("MapParts")
                                                                                   
                                                                        
        addRoot(parts,nil)
                                                                                  
                                                                                    
        for _,node in ipairs(safeChildren(ws)) do if node.Name=="Destructibles" and node.ClassName=="Folder" then addRoot(node,nil) end end
                                                                             
                                                                       
        local stuff=parts and parts:FindFirstChild("MapStuff")
        for _,node in ipairs(safeChildren(stuff)) do
            local kind=knownKind(node)
            if kind=="Bushes" or kind=="Grass" then addRoot(node,kind) end
        end
        for _,node in ipairs(safeChildren(ws)) do
            local kind=knownKind(node)
            if kind=="Grass" or kind=="Bushes" then addRoot(node,kind) end
        end
                                                                                  
                                                                                  
                                                                                  
    end
    local function visualTree(node,knownTree)
                                                                                   
        if node.Name~="VisualModel" or node.ClassName~="Model" then return false end
        local up=node:FindFirstChild("Up");local down=node:FindFirstChild("Down")
        if not up or not down then return false end
        local trunk,foliage=false,false
        for _,root in ipairs({up,down}) do for _,child in ipairs(safeChildren(root)) do
            local n=compact(child.Name)
            if n=="trunk" then trunk=true end
            if knownTree and n~="trunk" and child.ClassName=="MeshPart" then foliageNames[n]=true end
            if n=="leaf" or n=="leaves" or n=="foliage" or n=="branches"
                or foliageNames[n] or tostring(child.Name):lower():match("^tree[%._]") then foliage=true end
        end end
        return trunk and foliage
    end
    local function scanOne(frame,budget)
        local node=frame.node;local id=node and node.Address
        if frame.validation then
            if not id or not settings[frame.kind] then return 1 end
            local last=math.min(#frame.children,frame.index+math.min(64,budget or 64)-1)
            local count=0
            for i=frame.index,last do
                local child=frame.children[i];count+=1
                local class=child.ClassName
                if protected(child) or not classPart(class) and class~="Model" and class~="Folder" then
                    for j=#frame.children,1,-1 do stack[#stack+1]={node=frame.children[j],kind=frame.kind} end
                    return count
                end
                if class=="Model" or class=="Folder" then
                    for _,nested in ipairs(safeChildren(child)) do frame.children[#frame.children+1]=nested end
                end
            end
            frame.index=last+1;visited+=count
            if frame.index>#frame.children then hide(node,frame.kind) else stack[#stack+1]=frame end
            return math.max(1,count)
        end
        if not id or seen[id] or protected(node) then return end
        seen[id]=true;visited+=1
        local kind=frame.kind or knownKind(node)
        if settings.Trees and (visualTree(node,kind=="Trees") or kind=="Trees" and node.Name=="VisualModel" and node.ClassName=="Model") then hide(node,"Trees");return end
        local children=safeChildren(node)
                                                                               
                                                                                    
        if kind and settings[kind] and kind~="Trees" and node.ClassName=="Folder" then
            if #children>0 then
                stack[#stack+1]={node=node,kind=kind,validation=true,children=children,index=1}
                return 1
            end
        end
        if kind and settings[kind] and classPart(node.ClassName) then hide(node,kind);return end
        if node.ClassName=="Folder" or node.ClassName=="Model" then
            for i=#children,1,-1 do stack[#stack+1]={node=children[i],kind=kind} end
        end
    end
    local function updateLabel()
        local counts={Trees=0,Bushes=0,Grass=0}
        for _,r in pairs(records) do if counts[r.kind] then counts[r.kind]+=1 end end
        if controls.Status then controls.Status:SetValue("Hidden: "..counts.Trees.." trees, "..counts.Bushes.." bush groups, "..counts.Grass.." grass groups") end
        if controls.TerrainStatus then controls.TerrainStatus:SetValue("Terrain grass: "..terrainStatus) end
        if controls.LightStatus then controls.LightStatus:SetValue("Full bright: "..lightStatus) end
    end
    function module.install(section)
        assert(section and type(section.Toggle)=="function","World visuals need a UI section")
        if next(controls) then return module end
        if section.Heading then section:Heading("Vegetation") end
        for _,row in ipairs({{"Trees","Hide trees"},{"Bushes","Hide bushes"},{"Grass","Hide grass models"},{"TerrainGrass","Hide terrain grass"},{"NoFog",capabilities.LegacyFog and "No fog" or "No atmospheric haze"},{"NoPostFX","Disable post effects"},{"FullBright","Full bright"}}) do
            local key,label=row[1],row[2]
            if key=="NoFog" and section.Heading then section:Heading("Lighting") end
            local supported=capabilities[key]~=false
            if not supported then label..=" (unavailable)" end
            controls[key]=section:Toggle("thalassar_world_"..key:lower(),label,settings[key],function(value)
                settings[key]=supported and value==true
                if not supported then controls[key]:SetValue(false) end
                nextDiscovery=0
                nextLighting=0
            end)
            if not supported and controls[key].SetDisabled then controls[key]:SetDisabled(true) end
        end
        if section.Tip then section:Tip("Terrain grass and full bright require bound lighting fields; unsupported controls report their status.") end
        if section.Label then
            controls.Status=section:Label("World visuals ready")
            controls.TerrainStatus=section:Label("Terrain grass: "..terrainStatus)
            controls.LightStatus=section:Label("Full bright: "..lightStatus)
        end
        return module
    end
    function module.step(dt)
        if not session() then return end
        local t=now();if t-lastStep<.1 then return end;lastStep=t
        if t>=nextLighting then updateLighting();nextLighting=t+1 end
                                                                                 
        local before=now()
        local restoredThisStep=0
        local checked=0
        local limit=math.min(96,#order)
        while #order>0 and checked<limit do
            if nextRecord>#order then nextRecord=1 end
            local id=order[nextRecord];checked+=1
            local r=records[id]
            if not r or not settings[r.kind] and restoreRecord(id,false) then
                order[nextRecord]=order[#order];order[#order]=nil
                if r then restoredThisStep+=1 end
                if restoredThisStep>=32 then break end
            else nextRecord+=1 end
        end
        if not settings.Trees and not settings.Bushes and not settings.Grass then stack={};updateLabel();return end
        if #stack==0 and t>=nextDiscovery then discover();nextDiscovery=t+2 end
        local work=0
        while #stack>0 and work<160 and now()-before<.0025 do
            local frame=stack[#stack];stack[#stack]=nil;work+=scanOne(frame,160-work) or 1
        end
        updateLabel()
    end
    function module.export() local result={Version=1};for key,value in pairs(settings) do result[key]=value end;return result end
    function module.import(saved)
        if type(saved)~="table" then return false end
        for key in pairs(settings) do if type(saved[key])=="boolean" then settings[key]=capabilities[key]~=false and saved[key];if controls[key] then controls[key]:SetValue(settings[key]) end end end
        nextDiscovery=0;nextLighting=0;return true
    end
    function module.reset() local values={};for key in pairs(settings) do values[key]=false end;return module.import(values) end
    function module.status()
        local count,kinds=0,{}
        for _,r in pairs(records) do count+=1;kinds[r.kind]=(kinds[r.kind] or 0)+1 end
        return {running=running,place=place,job=job,records=count,kinds=kinds,changes=hidden,restored=restored,failures=failures,
            visited=visited,queued=#stack,queuedRecords=#order,scans=scans,terrain=terrainStatus,lighting=lightStatus}
    end
    function module.stop()
        if not running then return end
        if game.PlaceId==place and game.JobId==job then
            for _,id in ipairs(order) do restoreRecord(id,true) end
            restoreProperties(true)
        end
        running=false;stack={};roots={};order={};nextRecord=1
    end
    return module
end
return createThalassarWorldVisuals

end)()
local worldVisuals=createWorldVisuals()
assert(glass.BackgroundSection, "Thalassar background settings section missing")
effects.install(glass.BackgroundSection)
if previousEffects then effects.import(previousEffects) end
local function appearancePath(name)
    local clean = tostring(name or "default"):gsub("[^%w_%-]", "_"):sub(1, 48)
    return "Thalassar-Private.appearance." .. clean .. ".json"
end
glass.onProfileSaved = function(name)
    local bindings={}
    for id, value in pairs(glass.exportValues()) do
        if id:sub(-3)=="_kb" then bindings[id]=value end
    end
    writefile(appearancePath(name), Http:JSONEncode({schema=1, appearance=glass.exportAppearance(), bindings=bindings,
        effects=effects.export(),crosshairs=crosshairs.export(),world=worldVisuals.export()}))
    lastProfileResult = "Profile saved"
    glass.SetValue("thalassar_profile_status", lastProfileResult)
end
glass.onProfileLoaded = function(name)
    local path = appearancePath(name)
    if isfile(path) then
        local saved = Http:JSONDecode(readfile(path))
        assert(type(saved)=="table" and saved.schema==1, "Unsupported appearance profile")
        glass.importAppearance(saved.appearance or {})
        glass.importValues(saved.bindings or {}, false)
        if saved.effects then effects.import(saved.effects) end
        if saved.crosshairs then crosshairs.import(saved.crosshairs) end
        if saved.world then worldVisuals.import(saved.world) end
    end
    lastProfileResult = "Profile loaded"
    glass.SetValue("thalassar_profile_status", lastProfileResult)
end
glass.onProfileReset = function()
    glass.resetAppearance()
    effects.reset()
    crosshairs.reset()
    worldVisuals.reset()
    lastProfileResult = "Profile reset"
    glass.SetValue("thalassar_profile_status", lastProfileResult)
end
local function cleanupGlass()
    wheelBridge.close()
    if renderConnection then pcall(function() renderConnection:Disconnect() end); renderConnection = nil end
    pcall(crosshairs.stop)
    pcall(worldVisuals.stop)
    if glass then pcall(glass.destroy) end
end
local success, startupResult = pcall(function()
    return (function(UI)
                                                                            
                                                                                  
assert(type(UI)=="table" and type(UI.AddTab)=="function", "Thalassar UI adapter required")
local running, conn, suppliedConnection, suppliedStop = true, nil, nil, nil
local drawings = {}
local Runtime = {frames=0, errors={}, ready=false}
local function recordError(where, err)
    Runtime.errors[where] = tostring(err)
end
local function guarded(where, callback)
    local ok,err=pcall(callback)
    if not ok then recordError(where,err) end
    return ok,err
end
local function drawingNew(kind)
    local node = Drawing.new(kind)
    drawings[#drawings+1] = node
    return node
end
local function alive(node) return node and node.Parent~=nil end
local function numeric(node)
    if not node then return false end
    local c=node.ClassName
    return c=="NumberValue" or c=="IntValue" or c=="FloatValue" or c=="DoubleValue"
end
local function part(node)
    if not node then return false end
    local c=node.ClassName
    return c=="Part" or c=="MeshPart" or c=="UnionOperation" or c=="Seat" or c=="VehicleSeat"
end

if _G.MTC and _G.MTC.stop then pcall(_G.MTC.stop) end

local RS        = game:GetService("RunService")
local Players   = game:GetService("Players")
local LP        = Players.LocalPlayer
local Workspace = workspace

local FACTION_COLOR = {
    ["Eagle Federation"] = "Dark green",
    ["Hawk Republic"]    = "Bright red",
}
local myTeamColor = nil

local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local CFrame_new  = CFrame.new
local Color3_rgb  = Color3.fromRGB
local Color3_new  = Color3.new
local floor       = math.floor
local huge        = math.huge
local WTS         = WorldToScreen

local VERSION = "original-combined"
local FONT_SYS, FONT_MONO = 1, 5

local STUD_PER_M = 2.7777778
local STUDS_TO_M = 1 / STUD_PER_M
local FADE_START = 450
local FADE_END   = 3200
local ABANDONED  = "Unoccupied/Abandoned"
local DRONE_MAX  = 500

local COL_BOX    = Color3_rgb(255, 255, 255)
local COL_NAME   = Color3_rgb(255, 255, 255)
local COL_DIST   = Color3_rgb(140, 220, 255)
local COL_CLASS  = Color3_rgb(255, 180, 80)
local COL_OVR    = Color3_rgb(235, 235, 235)
local COL_ACC    = Color3_rgb(120, 200, 120)
local COL_DRONE  = Color3_rgb(120, 255, 180)
local COL_ENGINE = Color3_rgb(255, 140, 0)
local COL_AMMO   = Color3_rgb(255, 40, 40)
local MOD_FILL_A = 0.5

local COL_MISSILE = Color3_rgb(255, 170, 40)
local COL_THREAT  = Color3_rgb(255, 40, 40)
local MSL_MOVE2   = 4
local MSLPOOL     = 14

local RELOAD_VK   = 0x45
local FLARE_VK    = 0x47
local FLARE_RANGE = 900
local FLARE_COOL  = 5

local KD_DROP_Y   = -1000
local KD_ABOVE    = -600

local MOD_GROUP   = 32966202
local MOD_ROLES   = { { id = 348178106, name = "Administrator" }, { id = 347606116, name = "Moderator" }, { id = 348814130, name = "Content Creator" } }
local COL_STAFF   = Color3_rgb(255, 30, 60)
local STAFFPOOL   = 8

local COL_BALL    = Color3_rgb(120, 255, 180)

local PROJ_GRAV   = 17.64
local SHELL_VEL_DEFAULT = 1000

local Config = {
    Enabled = true, Box = true, Names = true, Class = true, Distance = true, Overlay = false,
    Fade = true, MaxDist = 3200, Heli = false, Drone = false, OccupiedOnly = false, TeamCheck = false,

    ModOutline = false, ModFilled = false, ModEngine = true, ModAmmo = true, ModMaxDist = 400,

    HideGrain = false, Missile = false, AutoReload = false, ModChecker = false, Ballistic = false,
    AutoFlare = false, ReloadStatus = false, KDDrop = false,
    ArmourOverride=false, ArmourValue=2.5, InfiniteATGM=false, InfiniteAutocannon=false,
    RapidFire=false, Usage=35, AutoRescan=false, SeatWatch=false, SeatFree=false,
    MouseAim=false, InstantStartup=false, InstantRefill=false, RefillModule=0,
    CustomCursor=false, CursorStyle=0, CursorRainbow=false, CursorSize=11,
    FOVCircle=false, FOVRadius=120, FOVColor=false, TargetSnapline=false,
    TargetMode=0, TargetModule=0, ModAction=0,
}

local configDefaults=table.clone(Config)

local BoxEdges = {
    { 1, 2 }, { 3, 4 }, { 1, 3 }, { 2, 4 },
    { 5, 6 }, { 7, 8 }, { 5, 7 }, { 6, 8 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local FaceTris = {
    { 1, 2, 4 }, { 1, 4, 3 },
    { 5, 6, 8 }, { 5, 8, 7 },
    { 1, 2, 6 }, { 1, 6, 5 },
    { 3, 4, 8 }, { 3, 8, 7 },
    { 1, 3, 7 }, { 1, 7, 5 },
    { 2, 4, 8 }, { 2, 8, 6 },
}

local CLASS_ABBR = {
    ["Main Battle Tank"] = "MBT", ["Medium Tank"] = "MT", ["Light Tank"] = "LT",
    ["Heavy Tank"] = "HT", ["Tank Destroyer"] = "TD", ["Infantry Fighting Vehicle"] = "IFV",
    ["Armored Personnel Carrier"] = "APC", ["Armoured Personnel Carrier"] = "APC",
    ["Self Propelled Howitzer"] = "SPH",
    ["Self Propelled Gun"] = "SPG",

    ["Self Propelled Anti Aircraft"] = "SPAA", ["Self-Propelled Anti-Aircraft"] = "SPAA",
    ["Self Propelled Anti-Aircraft"] = "SPAA", ["Self-Propelled Anti Aircraft"] = "SPAA",
    ["Self Propelled Anti-Air"] = "SPAA", ["Self Propelled Anti Air"] = "SPAA",
    ["Anti-Air"] = "AA",
    ["Attack Helicopter"] = "AH", ["Helicopter"] = "HELI",
}
local function classAbbr(s)
    if type(s) ~= "string" then return nil end
    return CLASS_ABBR[s] or s
end

local POOL    = 28
local MODPOOL = 18

local function newText()
    local t = drawingNew("Text"); t.Size = 13; t.Center = true; t.Outline = true; t.Font = FONT_SYS; t.Visible = false
    return t
end

local slots = {}
for i = 1, POOL do
    local s = { lines = {} }
    for j = 1, 12 do
        local l = drawingNew("Line"); l.Thickness = 1; l.Color = COL_BOX; l.Visible = false
        s.lines[j] = l
    end
    s.classBg=drawingNew("Square"); s.classBg.Filled=true; s.classBg.Color=Color3_rgb(235,235,235)
    s.classBg.ZIndex=0; s.classBg.Visible=false
    s.name = newText(); s.cls = newText(); s.dist = newText(); s.reload = newText()
    s.cls.ZIndex=1
    local mk = drawingNew("Circle"); mk.Thickness = 1.5; mk.NumSides = 16; mk.Filled = false; mk.Color = COL_BOX; mk.Visible = false
    s.marker = mk
    slots[i] = s
end
local function hideSlot(s)
    for j = 1, 12 do s.lines[j].Visible = false end
    s.name.Visible = false; s.cls.Visible = false; s.classBg.Visible=false; s.dist.Visible = false; s.reload.Visible = false; s.marker.Visible = false
end

local modSlots = {}
for i = 1, MODPOOL do
    local ms = { lines = {}, tris = {} }
    for j = 1, 12 do
        local l = drawingNew("Line"); l.Thickness = 1; l.Visible = false; ms.lines[j] = l
        local tr = drawingNew("Triangle"); tr.Filled = true; tr.Visible = false; ms.tris[j] = tr
    end
    modSlots[i] = ms
end
local function hideModSlot(ms)
    for j = 1, 12 do ms.lines[j].Visible = false; ms.tris[j].Visible = false end
end

local mslSlots = {}
for i = 1, MSLPOOL do
    local mk = drawingNew("Circle"); mk.Thickness = 1.5; mk.NumSides = 12; mk.Filled = false; mk.Visible = false
    local tag = drawingNew("Text"); tag.Size = 13; tag.Center = true; tag.Outline = true; tag.Font = FONT_SYS; tag.Visible = false
    mslSlots[i] = { marker = mk, tag = tag }
end
local function hideMslSlot(m) m.marker.Visible = false; m.tag.Visible = false end

local ovrBg = drawingNew("Square")
ovrBg.Filled = true; ovrBg.Rounding = 0; ovrBg.Color = Color3_rgb(10, 10, 12)
ovrBg.Transparency = 0.45; ovrBg.Position = Vector2_new(12, 12); ovrBg.Size = Vector2_new(168, 108); ovrBg.Visible = false
local ovrTitle = drawingNew("Text")
ovrTitle.Size = 14; ovrTitle.Font = FONT_MONO; ovrTitle.Outline = true; ovrTitle.Color = COL_ACC
ovrTitle.Position = Vector2_new(20, 18); ovrTitle.Visible = false
local ovrLines = {}
for i = 1, 5 do
    local t = drawingNew("Text"); t.Size = 13; t.Font = FONT_MONO; t.Outline = true; t.Color = COL_OVR
    t.Position = Vector2_new(20, 38 + (i - 1) * 16); t.Visible = false
    ovrLines[i] = t
end

local ballRay = drawingNew("Line")
ballRay.Thickness = 1.5; ballRay.Color = COL_BALL; ballRay.Transparency = 1; ballRay.Visible = false

local ballCrossH = drawingNew("Line")
ballCrossH.Thickness = 2; ballCrossH.Color = COL_BALL; ballCrossH.Transparency = 1; ballCrossH.Visible = false
local ballCrossV = drawingNew("Line")
ballCrossV.Thickness = 2; ballCrossV.Color = COL_BALL; ballCrossV.Transparency = 1; ballCrossV.Visible = false
local ballBg = drawingNew("Square")
ballBg.Filled = true; ballBg.Rounding = 0; ballBg.Color = Color3_rgb(8, 14, 11); ballBg.Transparency = 0.5; ballBg.Visible = false
local ballTitle = drawingNew("Text")
ballTitle.Size = 14; ballTitle.Font = FONT_MONO; ballTitle.Outline = true; ballTitle.Color = COL_BALL; ballTitle.Visible = false
local ballLines = {}
for i = 1, 5 do
    local t = drawingNew("Text"); t.Size = 13; t.Font = FONT_MONO; t.Outline = true; t.Color = COL_OVR; t.Visible = false
    ballLines[i] = t
end
local ballRange = drawingNew("Text")
ballRange.Size = 16; ballRange.Center = true; ballRange.Outline = true; ballRange.Font = FONT_MONO; ballRange.Color = COL_BALL; ballRange.Visible = false

local staffSlots = {}
for i = 1, STAFFPOOL do
    local mk = drawingNew("Circle"); mk.Thickness = 2; mk.NumSides = 20; mk.Filled = false; mk.Color = COL_STAFF; mk.Visible = false
    local tag = drawingNew("Text"); tag.Size = 13; tag.Center = true; tag.Outline = true; tag.Font = FONT_SYS; tag.Color = COL_STAFF; tag.Visible = false
    staffSlots[i] = { marker = mk, tag = tag }
end
local function hideStaffSlot(s) s.marker.Visible = false; s.tag.Visible = false end
local lastStaffDrawn = 0
local staffBg = drawingNew("Square")
staffBg.Filled = true; staffBg.Rounding = 0; staffBg.Color = Color3_rgb(22, 6, 8); staffBg.Transparency = 0.55; staffBg.Visible = false
local staffTitle = drawingNew("Text")
staffTitle.Size = 14; staffTitle.Font = FONT_MONO; staffTitle.Outline = true; staffTitle.Color = COL_STAFF; staffTitle.Visible = false
local staffLines = {}
for i = 1, STAFFPOOL do
    local t = drawingNew("Text"); t.Size = 13; t.Font = FONT_MONO; t.Outline = true; t.Color = Color3_rgb(255, 175, 185); t.Visible = false
    staffLines[i] = t
end
local staffPopup = drawingNew("Text")
staffPopup.Size = 22; staffPopup.Center = true; staffPopup.Outline = true; staffPopup.Font = FONT_MONO; staffPopup.Color = COL_STAFF; staffPopup.Visible = false

local cache = {}
local targets = {}

local function partCorners(part)
    local sz = part.Size
    if not sz then return nil end
    local hx, hy, hz = sz.X * 0.5, sz.Y * 0.5, sz.Z * 0.5
    return {
        { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz },
        { -hx, hy, -hz },  { hx, hy, -hz },  { -hx, hy, hz },  { hx, hy, hz },
    }
end

local function collectModules(veh)
    local out = {}
    local dm = veh:FindFirstChild("DamageModules")
    if not dm then return out end
    for _, mdl in ipairs(dm:GetChildren()) do
        for _, p in ipairs(mdl:GetChildren()) do
            local nm = p.Name
            local kind
            if nm == "Engine" then kind = "eng"
            elseif nm:match("^AmmoModel%d+$") then kind = "ammo" end
            if kind then
                local ok, cr = pcall(partCorners, p)
                if ok and cr then out[#out + 1] = { part = p, corners = cr, kind = kind } end
            end
        end
    end
    return out
end

local function ballCaliber(name)
    local mm = name:match("(%d+%.?%d*)%s*[mM][mM]")
    if mm then return tonumber(mm) end
    local cal = name:match("(%d+%.?%d*)%s*[Cc]al")
    if cal then return tonumber(cal) / 100 * 25.4 end
    return 0
end

local function ballMainGun(veh)
    local turrets = veh and veh:FindFirstChild("Turrets")
    local t1 = turrets and turrets:FindFirstChild("Turret1")
    local w = t1 and t1:FindFirstChild("Weapons")
    if not w then return nil end
    local best, bestCal
    for _, g in ipairs(w:GetChildren()) do
        local c = ballCaliber(g.Name)
        if c >= 20 and (not bestCal or c > bestCal) then best = g; bestCal = c end
    end
    return best
end

local function buildVehicle(veh)
    local hull = veh:FindFirstChild("Hull")
    local mass = hull and hull:FindFirstChild("Mass")
    if not mass then return nil end
    local corners = partCorners(mass)
    if not corners then return nil end
    local gun = ballMainGun(veh)
    return {
        anchor  = mass, name = veh.Name,
        kind    = veh:GetAttribute("Type"),
        class   = classAbbr(veh:GetAttribute("VehicleClass")),
        gun     = gun,
        loaded  = gun and gun:FindFirstChild("CurrentlyLoaded"),
        teamColor = veh:GetAttribute("Team"),
        ownerVal = veh:FindFirstChild("Owner"),
        replen  = veh:FindFirstChild("Replenishable"),
        occupied = true,
        corners = corners,
        mods    = collectModules(veh),
    }
end

local function buildDrone(m)
    local pp = m.PrimaryPart
    if not pp then return nil end
    return {
        anchor = pp, name = m.Name, kind = "Drone",
        tag = (m.Name:gsub("%s*Drone%s*", "")):gsub("^%s*(.-)%s*$", "%1"),
        teamColor = m:GetAttribute("Team"),
        ownerVal = m:FindFirstChild("Owner"),
        ownerTag = m:FindFirstChild("OwnershipTag"),
        occupied = true,
    }
end

local CLASS_TEAM_PALETTE = {
    darkgreen=Color3_rgb(40,127,71), brightred=Color3_rgb(196,40,28),
    reallyblack=Color3_rgb(17,17,17), deeporange=Color3_rgb(255,176,0),
}
local CLASS_FACTION_MARKER = {
    eagle="Dark green", hawk="Bright red", fish="Really black", schwalbenheim="Deep orange",
}
local CLASS_FACTION_ALIASES = {
    eagle="eagle", eaglefederation="eagle", darkgreen="eagle",
    hawk="hawk", hawkrepublic="hawk", brightred="hawk",
    fish="fish", fishstate="fish", reallyblack="fish",
    schwalbenheim="schwalbenheim", schwalbenheimrepublic="schwalbenheim", deeporange="schwalbenheim",
    schwabelhiem="schwalbenheim", schwabelhiemrepublic="schwalbenheim",
}
local function classificationMember(value,key)
    if type(value)~="table" and type(value)~="userdata" then return nil end
    local ok,result=pcall(function() return value[key] end)
    if ok then return result end
    return nil
end
local function classificationFaction(value,depth)
    depth=depth or 0
    if depth>3 then return nil end
    if type(value)=="string" then return CLASS_FACTION_ALIASES[value:lower():gsub("[%s%p]","")] end
    if type(value)=="table" or type(value)=="userdata" then
        local class=classificationMember(value,"ClassName")
        if class=="Team" then return classificationFaction(classificationMember(value,"Name"),depth+1) end
        if class=="StringValue" or class=="ObjectValue" then
            return classificationFaction(classificationMember(value,"Value"),depth+1)
        end
    end
    return nil
end
local function resolveClassificationFaction(veh)
    local team=veh:GetAttribute("Team")
    local faction=classificationFaction(team)
    if faction then return faction end
    faction=classificationFaction(veh:FindFirstChild("Team"))
    if faction then return faction end
    local owner=veh:FindFirstChild("Owner")
    local player=owner and owner.Value
    if type(player)=="string" then player=Players:FindFirstChild(player) end
    if player then
        local ok, ownerTeam=pcall(function() return player.Team end)
        if ok then return classificationFaction(ownerTeam) end
    end
    return nil
end
local function classificationRGB(value)
    local r,g,b=classificationMember(value,"R"),classificationMember(value,"G"),classificationMember(value,"B")
    if type(r)=="number" and type(g)=="number" and type(b)=="number"
        and r>=0 and r<=1 and g>=0 and g<=1 and b>=0 and b<=1 then
        return Color3_new(r,g,b)
    end
    return nil
end
local function classificationColor(value,depth)
    depth=depth or 0
    if depth>3 then return nil end
    if type(value)=="string" then
        local color=CLASS_TEAM_PALETTE[value:lower():gsub("[%s%p]","")]
        if color then return color,"brickcolor-palette" end
        return nil
    end
    local color=classificationRGB(value) or classificationRGB(classificationMember(value,"Color"))
    if color then return color,"native-color" end
    local class=classificationMember(value,"ClassName")
    if class=="Team" then return classificationColor(classificationMember(value,"TeamColor"),depth+1) end
    if class=="StringValue" or class=="ObjectValue" then return classificationColor(classificationMember(value,"Value"),depth+1) end
    local name=classificationMember(value,"Name")
    if type(name)=="string" then return classificationColor(name,depth+1) end
    return nil
end
local function classificationMarker(value,depth)
    depth=depth or 0
    if depth>3 then return nil end
    if type(value)=="string" then return value end
    local class=classificationMember(value,"ClassName")
    if class=="Team" then
        return classificationMarker(classificationMember(value,"TeamColor"),depth+1) or classificationMember(value,"Name")
    end
    if class=="StringValue" or class=="ObjectValue" then return classificationMarker(classificationMember(value,"Value"),depth+1) end
    local name=classificationMember(value,"Name")
    if type(name)=="string" then return name end
    if classificationRGB(value) then return "Color3" end
    return nil
end
local function resolveClassificationColor(veh,faction)
    local attribute=veh:GetAttribute("Team")
    local attributeColor,attributeKind=classificationColor(attribute)
    if attributeColor and attributeKind=="native-color" then
        return attributeColor,"vehicle-native-color",classificationMarker(attribute)
    end
    local attributeFaction=classificationFaction(attribute)
    local marker=veh:FindFirstChild("Team")
    local markerFaction=classificationFaction(marker)
    local markerMatches=not attributeFaction or markerFaction==attributeFaction
    local markerColor,markerKind
    if markerMatches then markerColor,markerKind=classificationColor(marker) end
    if markerColor and markerKind=="native-color" then
        return markerColor,"team-marker-native-color",classificationMarker(marker)
    end
    local owner=veh:FindFirstChild("Owner")
    local player=classificationMember(owner,"Value")
    if type(player)=="string" then player=Players:FindFirstChild(player) end
    local ownerTeam=classificationMember(player,"Team")
    local authoritativeFaction=attributeFaction or (markerMatches and markerFaction) or faction
    local ownerColor,ownerKind
    if ownerTeam and (not authoritativeFaction or classificationFaction(ownerTeam)==authoritativeFaction) then
        ownerColor,ownerKind=classificationColor(ownerTeam)
        if ownerColor and ownerKind=="native-color" then
            return ownerColor,"owner-team-native-color",classificationMarker(ownerTeam)
        end
    end
    if attributeColor then return attributeColor,"vehicle-"..attributeKind,classificationMarker(attribute) end
    if markerColor then return markerColor,"team-marker-"..markerKind,classificationMarker(marker) end
    if ownerColor then return ownerColor,"owner-team-"..ownerKind,classificationMarker(ownerTeam) end
    local knownMarker=faction and CLASS_FACTION_MARKER[faction]
    if knownMarker then
        return CLASS_TEAM_PALETTE[knownMarker:lower():gsub("[%s%p]","")],"faction-palette-fallback",knownMarker
    end
    return nil,"color-picker-fallback",classificationMarker(attribute)
end

local function resolveAlly(e, myTeamName)
    if myTeamColor and e.teamColor then return e.teamColor == myTeamColor end
    if not myTeamName then return nil end

    local ov = e.ownerVal
    local plr = ov and ov.Value
    if plr then
        local ok, tm = pcall(function() return plr.Team end)
        if ok and tm and tm.Name then return tm.Name == myTeamName end
    end

    local ot = e.ownerTag
    local nm = ot and ot.Value
    if type(nm) == "string" and nm ~= "" then
        local p2 = Players:FindFirstChild(nm)
        local ok, tm = pcall(function() return p2 and p2.Team end)
        if ok and tm and tm.Name then return tm.Name == myTeamName end
    end
    return nil
end

local GRAIN_ZERO = Vector2.new(0, 0)
local grainSizes = {}

local RSTORAGE = game:GetService("ReplicatedStorage")
local GRAIN_TEMPLATES = {
    { RSTORAGE, "PlaceableModels", "Drone", "Script", "ControlGUI", "Grain" },
    { RSTORAGE, "PlaceableModels", "Recon Drone", "Script", "ControlGUI", "Grain" },
    { RSTORAGE, "PlaceableModels", "RPG Drone", "Script", "ControlGUI", "Grain" },
    { RSTORAGE, "PlaceableModels", "Rifle Drone", "Script", "ControlGUI", "Grain" },
    { RSTORAGE, "PlaceableModels", "Lancet Launcher", "Script", "ScreenGui", "Grain" },
    { RSTORAGE, "TankModules", "Drones", "ControlGUI", "Grain" },
}

local grainList = {}
local grainTick = 0

local function refreshGrainAddrs()
    local out = {}
    local pg = LP and LP:FindFirstChild("PlayerGui")
    if pg then

        local ctrl = pg:FindFirstChild("ControlGUI")
        if ctrl then
            for _, d in ipairs(ctrl:GetDescendants()) do
                if d.Name == "Grain" then out[#out + 1] = d end
            end
        end
    end
    for i = 1, #GRAIN_TEMPLATES do
        local p = GRAIN_TEMPLATES[i]
        local node = p[1]
        for j = 2, #p do node = node and node:FindFirstChild(p[j]) end
        if node then out[#out + 1] = node end
    end
    grainList = out
end

local function enforceGrain()
    for i = 1, #grainList do
        pcall(function()
            local node=grainList[i]
            if node and node.Address and node.AbsoluteSize then
                if not grainSizes[node.Address] then grainSizes[node.Address]={node=node,size=node.AbsoluteSize} end
                node.AbsoluteSize=GRAIN_ZERO
            end
        end)
    end
end

local function restoreGrain()
    for i = 1, #grainList do
        pcall(function()
            local saved=grainSizes[grainList[i].Address]
            if saved then saved.node.AbsoluteSize=saved.size end
        end)
    end
    grainList = {}; grainSizes = {}
end

local PROJ = {}
do
    local function P(label, threat, names)
        for _, n in ipairs(names) do PROJ[n:lower()] = { label = label, threat = threat } end
    end
    P("AA",     true,  { "SAM", "SAM1", "SAM2", "SAM3", "StingerRocket", "PATRIOTProj", "aim9m", "kugelblitz" })
    P("ATGM",   false, { "wireatgm", "roketatgm", "KornetATGMModel", "302ATM", "DragonATGM", "nlawmis", "STURM", "SS.11", "losat", "testatgm", "Brimstone" })
    P("AGM",    false, { "agm65", "kh25ml", "kh35", "kh38mle" })
    P("Rocket", false, { "MLRSRocket", "RP3RocketModel", "RP3Rocket", "RGB-60", "roket", "roketbeg", "RPG", "IskanderRocket", "HERO-120" })
    P("Bomb",   true,  { "Bomb", "fab500m62", "mk842000lbs" })
end
local mslContainers = {}
do
    local ok, shells = pcall(function() return game:GetService("ReplicatedStorage").PHRST.Shells end)
    if ok and shells then local f = shells:FindFirstChild("PhysicalBullets"); if f then mslContainers[#mslContainers + 1] = f end end
    local ter = Workspace:FindFirstChild("Terrain"); if ter then mslContainers[#mslContainers + 1] = ter end
end
local mslTargets = {}
local mslPrev = {}
local lastMslDrawn = 0

local crewLoadBar = nil
local reloadArmed    = true
local reloadNextFire = 0
local reloadLastNX   = nil

local flareArmed  = true
local flareNextAt = 0
local function tapFlare()
    keypress(FLARE_VK); task.wait(0.05); pcall(keyrelease, FLARE_VK)
end
local function throwFlares()
    tapFlare(); task.wait(0.12); tapFlare()
    task.wait(1.6)
    tapFlare(); task.wait(0.12); tapFlare()
end

local modSet = {}
local modReady = false
local modTargets = {}
local modSeen = {}
local staffPopupText, staffPopupUntil = nil, 0
local HttpSvc = game:GetService("HttpService")
task.spawn(function()
    for _, r in ipairs(MOD_ROLES) do
        local url = "https://groups.roblox.com/v1/groups/" .. MOD_GROUP .. "/roles/" .. r.id .. "/users?limit=100&sortOrder=Asc"
        local ok, res = pcall(httpget, url)
        if ok and res then
            local dok, data = pcall(function() return HttpSvc:JSONDecode(res) end)
            if dok and type(data) == "table" and data.data then
                for _, u in ipairs(data.data) do
                    local uid = tonumber(u.userId)
                    if uid then modSet[uid] = r.name end
                end
            end
        end
        task.wait(0.2)
    end
    modReady = true
end)

local LocalPlayers = game:GetService("Players")

local function kdStaffPresent()
    if not modReady then return nil end
    local found
    pcall(function()
        local myId = LP and LP.UserId
        for _, pl in ipairs(LocalPlayers:GetPlayers()) do
            local uid = pl.UserId
            if uid and uid ~= myId and modSet[uid] then found = pl.Name; break end
        end
    end)
    return found
end

local kdEnabledCache = false
local kdPollClock = 0
local function kdEnabled()
    if Config.KDDrop then return true end
    if os.clock() - kdPollClock > 0.35 then
        local ok, v = pcall(UI.GetValue, "kd_drop")
        kdEnabledCache = (ok and v == true)
        kdPollClock = os.clock()
    end
    return kdEnabledCache
end

local kdLastDrop = 0
local kdWarned = false

task.spawn(function()
    while running do
      guarded("collector",function()
        local mt = LP and LP.Team
        local myTeamName = mt and mt.Name or nil
        myTeamColor = mt and FACTION_COLOR[mt.Name] or nil
        do
            local pg = LP and LP:FindFirstChild("PlayerGui")
            local cg = pg and pg:FindFirstChild("CrewGui")
            crewLoadBar = cg and cg:FindFirstChild("loadBar") or nil
        end

        if Config.HideGrain then
            grainTick = grainTick + 1
            if grainTick >= 4 or #grainList == 0 then grainTick = 0; refreshGrainAddrs() end
        end
        local out = {}
        local sv = Workspace:FindFirstChild("SpawnedVehicles")
        if sv then
            local seen = {}
            for _, veh in ipairs(sv:GetChildren()) do
                local addr = veh.Address
                if addr then
                    seen[addr] = true
                    local e = cache[addr]
                    if not e then e = buildVehicle(veh); cache[addr] = e or false end
                    if e then
                        e.classFaction=resolveClassificationFaction(veh)
                        e.classColor,e.classColorSource,e.classTeamMarker=resolveClassificationColor(veh,e.classFaction)
                        e.occupied = veh:GetAttribute("Occupied") ~= false
                        e.ally = resolveAlly(e, myTeamName)
                        out[#out + 1] = e
                    end
                end
            end

            local pb = Workspace:FindFirstChild("PlacedBuildings")
            if pb and Config.Drone then
                for _, m in ipairs(pb:GetChildren()) do
                    if m:GetAttribute("Drone") then
                        local addr = m.Address

                        local pp = m.PrimaryPart
                        if addr and pp then
                            seen[addr] = true
                            local e = cache[addr]
                            if e == nil then e = buildDrone(m); cache[addr] = e or false end
                            if e then
                                e.anchor = pp
                                e.ally = resolveAlly(e, myTeamName)
                                out[#out + 1] = e
                            end
                        elseif addr then
                            cache[addr] = nil
                        end
                    end
                end
            end
            for addr in pairs(cache) do if not seen[addr] then cache[addr] = nil end end
        end

        if Config.ModChecker and modReady then
            local mout = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.UserId ~= LP.UserId then
                    local role = modSet[pl.UserId]
                    if role then
                        local ch = pl.Character
                        local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head"))
                        mout[#mout + 1] = { root = root, name = pl.Name, role = role }
                        if not modSeen[pl.UserId] then
                            modSeen[pl.UserId] = true
                            pcall(notify, "STAFF IN SERVER", role .. ": " .. pl.Name, 8)
                            staffPopupText = role:upper() .. "  -  " .. pl.Name .. "  IS IN THE SERVER"
                            staffPopupUntil = tick() + 6
                        end
                    end
                end
            end
            modTargets = mout
        elseif #modTargets > 0 and not Config.ModChecker then
            modTargets = {}
        end
        targets = out
      end)
        task.wait(0.5)
    end
end)

task.spawn(function()
    while running do
      guarded("missiles",function()
        if Config.Missile or Config.AutoFlare then
            local mout, mseen = {}, {}

            local myPos
            if Config.AutoFlare then
                local ch = LP and LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                myPos = hrp and hrp.Position
                if not myPos then local cc = Workspace.CurrentCamera; myPos = cc and cc.CFrame.Position end
            end
            local threatNear = false
            for _, cont in ipairs(mslContainers) do
                for _, c in ipairs(cont:GetChildren()) do
                    local cn = c.ClassName
                    local anchor
                    if cn == "MeshPart" or cn == "Part" or cn == "UnionOperation" then anchor = c
                    elseif cn == "Model" then anchor = c.PrimaryPart end
                    if anchor then
                        local cat = PROJ[c.Name:lower()]
                        if cat then
                            local a2 = c.Address
                            local pp = anchor.Position
                            if a2 and pp then
                                mseen[a2] = true
                                local px, py, pz = pp.X, pp.Y, pp.Z
                                local moving = false
                                local vel = anchor.AssemblyLinearVelocity
                                if vel and (vel.X * vel.X + vel.Y * vel.Y + vel.Z * vel.Z) > 100 then moving = true end
                                local pv = mslPrev[a2]
                                local mvx, mvy, mvz = 0, 0, 0
                                if pv then
                                    mvx, mvy, mvz = px - pv[1], py - pv[2], pz - pv[3]
                                    if not moving and (mvx * mvx + mvy * mvy + mvz * mvz) > MSL_MOVE2 then moving = true end
                                    pv[1], pv[2], pv[3] = px, py, pz
                                else
                                    mslPrev[a2] = { px, py, pz }
                                end
                                if moving then
                                    mout[#mout + 1] = { anchor = anchor, label = cat.label, threat = cat.threat }

                                    if Config.AutoFlare and cat.threat and cat.label == "AA" and myPos and pv then
                                        local tmx, tmy, tmz = myPos.X - px, myPos.Y - py, myPos.Z - pz
                                        if (tmx * tmx + tmy * tmy + tmz * tmz) < (FLARE_RANGE * FLARE_RANGE)
                                           and (mvx * tmx + mvy * tmy + mvz * tmz) > 0 then
                                            threatNear = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            for a2 in pairs(mslPrev) do if not mseen[a2] then mslPrev[a2] = nil end end
            mslTargets = mout

            if Config.AutoFlare then
                if threatNear and flareArmed and os.clock() >= flareNextAt then
                    flareArmed = false
                    flareNextAt = os.clock() + FLARE_COOL
                    pcall(notify, "THREAT", "SAM inbound, deploying flares", 3)
                    task.spawn(throwFlares)
                elseif not threatNear then
                    flareArmed = true
                end
            end
        elseif #mslTargets > 0 then
            mslTargets = {}
            for k in pairs(mslPrev) do mslPrev[k] = nil end
        end
      end)
        task.wait(0.1)
    end
end)

local ballResult = nil
local function ballVehOf(inst)
    local sv = Workspace:FindFirstChild("SpawnedVehicles")
    local svA = sv and sv.Address
    local n = inst
    while n and n.Parent do
        local pa = n.Parent.Address
        if pa and svA and pa == svA then return n end
        n = n.Parent
    end
end

local function ballOwnVehicle()
    local ch = LP and LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local prm = RaycastParams.new(); prm.FilterType = Enum.RaycastFilterType.Exclude; prm.FilterDescendantsInstances = { ch }
    local r = Workspace:Raycast(hrp.Position, Vector3_new(0, -60, 0), prm)
    return (r and ballVehOf(r.Instance)) or nil, ch
end

local function ballBarrel(gun)
    if not gun then return nil end
    local current=gun:FindFirstChild("CurrentMuzzle")
    local node=current and current.Value
    if part(node) then return node end
    if node and node.ClassName=="ObjectValue" and part(node.Value) then return node.Value end
    local muzzle=gun:FindFirstChild("Muzzle")
    return muzzle and part(muzzle.Value) and muzzle.Value or nil
end

local function ballOptic(veh)
    local turrets = veh and veh:FindFirstChild("Turrets")
    local t1 = turrets and turrets:FindFirstChild("Turret1")
    local cams = t1 and t1:FindFirstChild("Cameras")
    if not cams then return nil end
    for _, nm in ipairs({ "MainSight", "TelescopeSight", "PeriscopeSight", "GunnerSight" }) do
        local o = cams:FindFirstChild(nm)
        if o and o.Value and o.Value.CFrame then return o.Value end
    end
    for _, o in ipairs(cams:GetChildren()) do
        local ln = o.Name:lower()
        if o.Value and o.Value.CFrame and not ln:find("backup") and not ln:find("mg") then return o.Value end
    end
    return nil
end

local function ballHullCenter(veh)
    local sx, sy, sz, n = 0, 0, 0, 0
    for _, d in ipairs(veh:GetDescendants()) do
        local cn = d.ClassName
        if cn == "Part" or cn == "MeshPart" then
            local p = d.Position; sx = sx + p.X; sy = sy + p.Y; sz = sz + p.Z; n = n + 1
        end
    end
    if n == 0 then return nil end
    return Vector3_new(sx / n, sy / n, sz / n)
end

local ballShellMap = {}
local function ballBuildShellMap()
    local map = {}
    local pg = LP and LP:FindFirstChild("PlayerGui")
    local cg = pg and pg:FindFirstChild("CrewGui")
    if not cg then return map end
    for _, d in ipairs(cg:GetDescendants()) do
        if d.Name == "AmmoName" and d.ClassName == "TextLabel" and d.Text and d.Text ~= "" then
            local entry = d.Parent
            local dt = entry and entry:FindFirstChild("DataTable")
            local velL = dt and dt:FindFirstChild("Velocity")
            if velL then
                local v = tonumber((velL.Text or ""):match("(%d+)"))
                if v then
                    local typeL = entry:FindFirstChild("AmmoType")
                    map[d.Text] = { vel = v, typ = (typeL and typeL.Text) or "" }
                end
            end
        end
    end
    return map
end
task.spawn(function()
    local ballVehA, ballSign = nil, 1
    local vehClock = 0
    local shellClock = 0
    local cVeh, cCh = nil, nil
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    while running do
        local fast = false

        guarded("ballistic",function()
            if not Config.Ballistic then
                if ballResult then ballResult = nil end
                return
            end
            local pg = LP and LP:FindFirstChild("PlayerGui")
            local crewing = pg and pg:FindFirstChild("CrewGui")
            if not crewing then ballResult = nil; return end

            if os.clock() - vehClock > 0.5 then cVeh, cCh = ballOwnVehicle(); vehClock = os.clock() end
            local veh, ch = cVeh, cCh
            local gun = veh and ballMainGun(veh)

            local barrel = gun and ballBarrel(gun)
            local optic  = veh and ballOptic(veh)
            local part   = barrel or optic
            local pcf = part and part.CFrame
            if not pcf then ballResult = nil; return end
            fast = true
            local o = pcf.Position
            local dir = pcf.LookVector
            local vehA = veh.Address
            if vehA ~= ballVehA then
                local center = ballHullCenter(veh)
                ballSign = (center and dir:Dot(o - center) < 0) and -1 or 1
                ballVehA = vehA
            end
            dir = dir * ballSign
            local refPos = (optic and optic.CFrame and optic.CFrame.Position) or o
            rp.FilterDescendantsInstances = { ch, veh }
            local origin, hit = o, nil
            for _ = 1, 4 do
                local r = Workspace:Raycast(origin, dir * 9000, rp)
                if not r then break end
                local hv = ballVehOf(r.Instance)
                local ownHit = (hv and hv.Address == vehA) or (ch and r.Instance:IsDescendantOf(ch))
                if ownHit then origin = r.Position + dir * 3 else hit = r; break end
            end
            if hit then
                local studs = (hit.Position - refPos).Magnitude
                local loaded = gun and gun:FindFirstChild("CurrentlyLoaded")
                local sname = loaded and loaded.Value
                local sd = sname and ballShellMap[sname]

                if not sd and sname and sname ~= "" and sname ~= "Unloaded" and (os.clock() - shellClock) > 2 then
                    ballShellMap = ballBuildShellMap(); shellClock = os.clock()
                    sd = ballShellMap[sname]
                end
                local vel = (sd and sd.vel) or SHELL_VEL_DEFAULT
                local flightT = studs / (vel * STUD_PER_M)
                ballResult = {
                    distM = studs * STUDS_TO_M, hitPos = hit.Position, originPos = o,
                    shell = sname, shType = sd and sd.typ, vel = vel, flightT = flightT,
                    dropM = (0.5 * PROJ_GRAV * flightT * flightT) * STUDS_TO_M,
                }
            else
                ballResult = { distM = nil, originPos = o, tipPos = o + dir * 300 }
            end
        end)
        task.wait(fast and 0.05 or 0.35)
    end
end)

local fps = 60
local PTS, FRONT   = {}, {}
local MPTS, MFRONT = {}, {}
local lastDrawn, lastModDrawn = 0, 0

local cpCache = {}
local cpClock = 0
local function readCP(id, defCol, defA)
    local now = os.clock()
    if now - cpClock > 0.25 then cpCache = {}; cpClock = now end
    local hit = cpCache[id]
    if hit then return hit[1], hit[2] end
    local col, al = defCol, defA
    local ok, r, g, b, a = pcall(UI.GetValue, id)
    if ok and type(r) == "number" then
        if type(g) == "number" and type(b) == "number" then
            col = Color3_rgb(r, g, b)
        end
        if type(a) == "number" then al = a / 255 end
    end
    cpCache[id] = { col, al }
    return col, al
end

local function projectBox(cf, corners, pts, front, sw, sh)
    local center = cf.Position
    local rv, uv, lv = cf.RightVector, cf.UpVector, cf.LookVector
    local px, py, pz = center.X, center.Y, center.Z
    local rx, ry, rz = rv.X, rv.Y, rv.Z
    local ux, uy, uz = uv.X, uv.Y, uv.Z
    local lx, ly, lz = lv.X, lv.Y, lv.Z
    local anyVis = false
    local minX, minY, maxX = huge, huge, -huge
    for c = 1, 8 do
        local lc = corners[c]
        local ax, ay, az = lc[1], lc[2], lc[3]
        local sp, vis = WTS(Vector3_new(px + rx * ax + ux * ay - lx * az, py + ry * ax + uy * ay - ly * az, pz + rz * ax + uz * ay - lz * az))
        if vis and sp then
            local x, y = floor(sp.X + 0.5), floor(sp.Y + 0.5)
            pts[c] = Vector2_new(x, y); front[c] = true
            local cxp = x < 0 and 0 or (x > sw and sw or x)
            local cyp = y < 0 and 0 or (y > sh and sh or y)
            if cxp < minX then minX = cxp end
            if cxp > maxX then maxX = cxp end
            if cyp < minY then minY = cyp end
            if x >= 0 and y >= 0 and x <= sw and y <= sh then anyVis = true end
        else
            front[c] = false
        end
    end
    return anyVis, minX, minY, maxX
end

local function drawEdges(lines, pts, front, col, alpha)
    for j = 1, 12 do
        local e = BoxEdges[j]
        local l = lines[j]
        local a, b = e[1], e[2]
        if front[a] and front[b] then
            l.From = pts[a]; l.To = pts[b]; l.Color = col; l.Transparency = alpha; l.Visible = true
        else
            l.Visible = false
        end
    end
end

local function drawFaces(tris, pts, front, col, alpha)
    for j = 1, 12 do
        local f = FaceTris[j]
        local tr = tris[j]
        local a, b, c = f[1], f[2], f[3]
        if front[a] and front[b] and front[c] then
            tr.PointA = pts[a]; tr.PointB = pts[b]; tr.PointC = pts[c]
            tr.Color = col; tr.Filled = true; tr.Transparency = alpha; tr.Visible = true
        else
            tr.Visible = false
        end
    end
end

local function originalFrame(dt)
    Runtime.frames += 1
    if not running then return end
    if dt and dt > 0 then fps = fps * 0.9 + (1 / dt) * 0.1 end

    if kdEnabled() then
        local staff = kdStaffPresent()
        if staff then
            if not kdWarned then pcall(notify, "KD DROPPER", "Staff in server (" .. tostring(staff) .. ") - paused", 4); kdWarned = true end
        else
            kdWarned = false
            local ch = LP and LP.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp and (os.clock() - kdLastDrop) > 0.3 then
                local p = hrp.Position
                if p.Y > KD_ABOVE then
                    pcall(function() hrp.CFrame = CFrame_new(p.X, KD_DROP_Y, p.Z) end)
                    kdLastDrop = os.clock()
                end
            end
        end
    else
        kdWarned = false
    end

    if Config.AutoReload and crewLoadBar then
        local needle, win
        for _, d in ipairs(crewLoadBar:GetDescendants()) do
            local n = d.Name
            if n == "Needle" then needle = d elseif n == "FastReloadWindow" then win = d end
        end
        if needle and win then
            local nAbs, wAbs, wSz = needle.AbsolutePosition, win.AbsolutePosition, win.AbsoluteSize
            if nAbs and wAbs and wSz and wSz.X > 0 then
                local nx = nAbs.X + 1
                local ws, we = wAbs.X, wAbs.X + wSz.X
                local now = tick()

                if reloadLastNX and nx < reloadLastNX - 50 then reloadArmed = true end
                if reloadArmed and now >= reloadNextFire and reloadLastNX then
                    local lo, hi = reloadLastNX, nx
                    if lo > hi then lo, hi = hi, lo end
                    if lo <= we and hi >= ws then
                        reloadArmed = false
                        reloadNextFire = now + 1.0
                        keypress(RELOAD_VK)
                        task.delay(0.045, function() pcall(keyrelease, RELOAD_VK) end)
                    end
                end
                reloadLastNX = nx
            end
        else
            reloadArmed = true; reloadLastNX = nil
        end
    end

    if Config.HideGrain then enforceGrain() end

    ovrBg.Visible = Config.Overlay; ovrTitle.Visible = Config.Overlay
    for i = 1, 5 do ovrLines[i].Visible = Config.Overlay end

    if Config.Ballistic and ballResult then

        local ballCol, ballA = readCP("misc_ball_col", COL_BALL, 1)
        ballRay.Color = ballCol; ballRay.Transparency = ballA
        ballCrossH.Color = ballCol; ballCrossH.Transparency = ballA
        ballCrossV.Color = ballCol; ballCrossV.Transparency = ballA
        ballRange.Color = ballCol; ballRange.Transparency = ballA
        ballTitle.Color = ballCol; ballTitle.Transparency = ballA
        ballBg.Transparency = 0.5 * ballA
        for i = 1, 5 do ballLines[i].Transparency = ballA end
        local bcam = Workspace.CurrentCamera
        local bvp = bcam and bcam.ViewportSize
        local vpy = (bvp and bvp.Y) or 1080
        local px, py = 12, vpy - 138
        ballBg.Position = Vector2_new(px, py); ballBg.Size = Vector2_new(184, 122); ballBg.Visible = true
        ballTitle.Text = "BALLISTIC"; ballTitle.Position = Vector2_new(px + 10, py + 6); ballTitle.Visible = true

        local sO, visO = WTS(ballResult.originPos)
        if ballResult.distM then
            local sH, visH = WTS(ballResult.hitPos)
            if visH and sH then
                local x, y = floor(sH.X + 0.5), floor(sH.Y + 0.5)
                local h = 11
                ballCrossH.From = Vector2_new(x - h, y); ballCrossH.To = Vector2_new(x + h, y); ballCrossH.Visible = true
                ballCrossV.From = Vector2_new(x, y - h); ballCrossV.To = Vector2_new(x, y + h); ballCrossV.Visible = true
                ballRange.Text = string.format("%.0f m", ballResult.distM)
                ballRange.Position = Vector2_new(x, y + 12); ballRange.Visible = true
                if visO and sO then
                    ballRay.From = Vector2_new(floor(sO.X + 0.5), floor(sO.Y + 0.5)); ballRay.To = Vector2_new(x, y); ballRay.Visible = true
                else ballRay.Visible = false end
            else
                ballCrossH.Visible = false; ballCrossV.Visible = false; ballRange.Visible = false; ballRay.Visible = false
            end
            local shell = ballResult.shell or "?"
            if ballResult.shType and ballResult.shType ~= "" then shell = shell .. " (" .. ballResult.shType .. ")" end
            ballLines[1].Text = string.format("Range   %.0f m", ballResult.distM)
            ballLines[2].Text = "Shell   " .. shell
            ballLines[3].Text = string.format("Vel     %d m/s", ballResult.vel or 0)
            ballLines[4].Text = string.format("Flight  ~%.2f s", ballResult.flightT)
            ballLines[5].Text = string.format("Drop    ~%.2f m", ballResult.dropM)
            for i = 1, 5 do ballLines[i].Position = Vector2_new(px + 10, py + 27 + (i - 1) * 17); ballLines[i].Visible = true end
        else

            ballCrossH.Visible = false; ballCrossV.Visible = false; ballRange.Visible = false
            local sT, visT = WTS(ballResult.tipPos or ballResult.originPos)
            if visO and sO and visT and sT then
                ballRay.From = Vector2_new(floor(sO.X + 0.5), floor(sO.Y + 0.5)); ballRay.To = Vector2_new(floor(sT.X + 0.5), floor(sT.Y + 0.5)); ballRay.Visible = true
            else ballRay.Visible = false end
            ballLines[1].Text = "Range   (no target)"; ballLines[1].Position = Vector2_new(px + 10, py + 27); ballLines[1].Visible = true
            for i = 2, 5 do ballLines[i].Visible = false end
        end
    else
        ballCrossH.Visible = false; ballCrossV.Visible = false; ballRange.Visible = false; ballRay.Visible = false
        ballBg.Visible = false; ballTitle.Visible = false
        for i = 1, 5 do ballLines[i].Visible = false end
    end

    if not Config.Enabled then
        for i = 1, lastDrawn do hideSlot(slots[i]) end
        for i = 1, lastModDrawn do hideModSlot(modSlots[i]) end
        lastDrawn, lastModDrawn = 0, 0
        if Config.Overlay then ovrTitle.Text = "BUYCHEAT.ORG  [off]"; for i = 1, 5 do ovrLines[i].Text = "" end end
        return
    end

    local cam = Workspace.CurrentCamera
    local camCF = cam and cam.CFrame
    local eye = camCF and camCF.Position
    local look = camCF and camCF.LookVector
    local vp  = cam and cam.ViewportSize
    local sw  = (vp and vp.X) or 1920
    local sh  = (vp and vp.Y) or 1080
    local list = targets
    local showBox, showName, showClass, showDist = Config.Box, Config.Names, Config.Class, Config.Distance
    local fade, maxDist = Config.Fade, Config.MaxDist
    local heliOn, droneOn, occOnly, teamChk = Config.Heli, Config.Drone, Config.OccupiedOnly, Config.TeamCheck
    local modOn = (Config.ModOutline or Config.ModFilled) and (Config.ModEngine or Config.ModAmmo)
    local modMax = Config.ModMaxDist
    local engCol, engA = readCP("mod_engine_col", COL_ENGINE, MOD_FILL_A)
    local ammoCol, ammoA = readCP("mod_ammo_col", COL_AMMO, MOD_FILL_A)

    local boxCol, boxA     = readCP("mtc_box_col",   COL_BOX,   1)
    local nameCol, nameA   = readCP("mtc_name_col",  COL_NAME,  1)
    local classCol, classA = readCP("mtc_class_col", COL_CLASS, 1)
    local distCol, distA   = readCP("mtc_dist_col",  COL_DIST,  1)

    local detected = #list
    local drawn, modDrawn = 0, 0
    local nearName, nearM = nil, huge

    for i = 1, detected do
        if drawn >= POOL then break end
        local t = list[i]
        local isHeli = (t.kind == "Heli")
        local isDrone = (t.kind == "Drone")

        if (isHeli and not heliOn) or (isDrone and not droneOn) or (occOnly and not t.occupied)
            or (teamChk and t.ally == true) then

        else
            local anchor = t.anchor
            local cf = anchor and anchor.CFrame
            if cf then
                local center = cf.Position
                local dm, behind = nil, false
                if eye then
                    local rel = center - eye
                    dm = floor(rel.Magnitude * STUDS_TO_M)
                    if dm < nearM then nearM = dm; nearName = t.name end
                    if look and rel:Dot(look) <= 0 then behind = true end
                end

                local skip = behind or (dm ~= nil and dm > (isDrone and DRONE_MAX or maxDist))
                local alpha = 1
                if fade and dm and not isDrone then
                    alpha = (FADE_END - dm) / (FADE_END - FADE_START)
                    if alpha > 1 then alpha = 1 elseif alpha <= 0 then skip = true; alpha = 0 end
                end

                if not skip then
                    local fsize = 14
                    if dm then fsize = 14 - dm * 0.004; if fsize < 9 then fsize = 9 elseif fsize > 14 then fsize = 14 end; fsize = floor(fsize + 0.5) end
                    local step = fsize + 2

                    if isHeli or isDrone then

                        local sp, vis = WTS(center)
                        if vis and sp then
                            local x, y = floor(sp.X + 0.5), floor(sp.Y + 0.5)
                            if x >= 0 and x <= sw and y >= 0 and y <= sh then
                                drawn = drawn + 1
                                local s = slots[drawn]
                                for j = 1, 12 do s.lines[j].Visible = false end
                                s.marker.Position = Vector2_new(x, y); s.marker.Radius = fsize * 0.5
                                s.marker.Color = isDrone and COL_DRONE or boxCol
                                s.marker.Transparency = isDrone and alpha or (alpha * boxA); s.marker.Visible = isDrone or showBox
                                s.cls.Visible = false; s.classBg.Visible=false
                                local yy = y - floor(fsize * 0.5) - 4 - fsize
                                if isDrone then

                                    s.dist.Visible = false
                                    s.name.Size = fsize; s.name.Text = t.tag; s.name.Color = COL_DRONE
                                    s.name.Transparency = alpha; s.name.Position = Vector2_new(x, yy); s.name.Visible = true
                                else
                                    if showDist and dm then
                                        s.dist.Size = fsize; s.dist.Text = dm .. "m"; s.dist.Color = distCol
                                        s.dist.Transparency = alpha * distA; s.dist.Position = Vector2_new(x, yy); s.dist.Visible = true; yy = yy - step
                                    else s.dist.Visible = false end
                                    if showName then
                                        s.name.Size = fsize; s.name.Text = t.name; s.name.Color = nameCol
                                        s.name.Transparency = alpha * nameA; s.name.Position = Vector2_new(x, yy); s.name.Visible = true
                                    else s.name.Visible = false end
                                end
                            end
                        end
                    else
                        local anyVis, minX, minY, maxX = projectBox(cf, t.corners, PTS, FRONT, sw, sh)
                        if anyVis then
                            drawn = drawn + 1
                            local s = slots[drawn]
                            s.marker.Visible = false; s.classBg.Visible=false

                            if showBox then drawEdges(s.lines, PTS, FRONT, boxCol, alpha * boxA)
                            else for j = 1, 12 do s.lines[j].Visible = false end end

                            local cx = floor((minX + maxX) / 2)
                            local yy = minY - 4 - fsize

                            if showDist and dm then
                                s.dist.Size = fsize; s.dist.Text = dm .. "m"; s.dist.Color = distCol
                                s.dist.Transparency = alpha * distA; s.dist.Position = Vector2_new(cx, yy); s.dist.Visible = true; yy = yy - step
                            else s.dist.Visible = false end
                            if showName then
                                s.name.Size = fsize; s.name.Text = t.name; s.name.Color = nameCol
                                s.name.Transparency = alpha * nameA; s.name.Position = Vector2_new(cx, yy); s.name.Visible = true; yy = yy - step
                            else s.name.Visible = false end
                            if showClass and t.class then
                                local factionColor=t.classColor or classCol
                                s.cls.Size = fsize; s.cls.Text = t.class; s.cls.Color = factionColor
                                s.classTarget=t.name; s.classFaction=t.classFaction
                                s.classColorSource=t.classColorSource; s.classTeamMarker=t.classTeamMarker
                                s.classRGB={floor(factionColor.R*255+.5),floor(factionColor.G*255+.5),floor(factionColor.B*255+.5)}
                                s.cls.Transparency = alpha * classA; s.cls.Position = Vector2_new(cx, yy); s.cls.Visible = true
                                if t.classFaction=="fish" then
                                    local bounds=s.cls.TextBounds
                                    local width=bounds and bounds.X or (#t.class*fsize*.65)
                                    local height=bounds and bounds.Y or fsize
                                    if width<=0 then width=#t.class*fsize*.65 end
                                    if height<=0 then height=fsize end
                                    s.classBg.Position=Vector2_new(cx-width*.5-2,yy-1)
                                    s.classBg.Size=Vector2_new(width+4,height+2)
                                    s.classBg.Transparency=alpha*classA; s.classBg.Visible=true
                                end
                                yy = yy - step
                            else s.cls.Visible = false end

                            if Config.ReloadStatus and t.gun then
                                local rl = t.gun:GetAttribute("reloading")
                                local reloading = (rl == true) or (type(rl) == "string" and rl ~= "" and rl:lower() ~= "false")
                                local loadedName = t.loaded and t.loaded.Value
                                local chambered = loadedName ~= nil and loadedName ~= "" and loadedName ~= "Unloaded"
                                local txt, col
                                if reloading then txt, col = "RELOADING", COL_CLASS
                                elseif chambered then txt, col = "READY", COL_ACC
                                else txt, col = "EMPTY", COL_AMMO end
                                s.reload.Size = fsize
                                s.reload.Text = txt; s.reload.Color = col
                                s.reload.Transparency = alpha; s.reload.Position = Vector2_new(cx, yy); s.reload.Visible = true
                            else s.reload.Visible = false end

                            if modOn and dm and dm <= modMax then
                                local mods = t.mods
                                for mi = 1, #mods do
                                    if modDrawn >= MODPOOL then break end
                                    local m = mods[mi]
                                    if (m.kind == "eng" and Config.ModEngine) or (m.kind == "ammo" and Config.ModAmmo) then
                                        local mcf = m.part.CFrame
                                        if mcf then
                                            local mvis = projectBox(mcf, m.corners, MPTS, MFRONT, sw, sh)
                                            if mvis then
                                                modDrawn = modDrawn + 1
                                                local ms = modSlots[modDrawn]
                                                local isEng = (m.kind == "eng")
                                                local col = isEng and engCol or ammoCol
                                                if Config.ModOutline then drawEdges(ms.lines, MPTS, MFRONT, col, 1)
                                                else for j = 1, 12 do ms.lines[j].Visible = false end end
                                                if Config.ModFilled then drawFaces(ms.tris, MPTS, MFRONT, col, isEng and engA or ammoA)
                                                else for j = 1, 12 do ms.tris[j].Visible = false end end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = drawn + 1, lastDrawn do hideSlot(slots[i]) end
    for i = modDrawn + 1, lastModDrawn do hideModSlot(modSlots[i]) end
    lastDrawn, lastModDrawn = drawn, modDrawn

    local mdrawn = 0
    if Config.Missile then
        local ml = mslTargets
        local cam = Workspace.CurrentCamera
        local campos = cam and cam.CFrame.Position
        for i = 1, #ml do
            if mdrawn >= MSLPOOL then break end
            local t = ml[i]
            local anchor = t.anchor
            if anchor and anchor.Parent then
                local pos = anchor.Position
                local sp, vis = WTS(pos)
                if vis and sp then
                    mdrawn = mdrawn + 1
                    local m = mslSlots[mdrawn]
                    local col = t.threat and COL_THREAT or COL_MISSILE
                    local x, y = floor(sp.X + 0.5), floor(sp.Y + 0.5)
                    m.marker.Position = Vector2_new(x, y); m.marker.Radius = 6
                    m.marker.Color = col; m.marker.Transparency = 1; m.marker.Visible = true
                    local lbl = t.label
                    if campos then lbl = lbl .. "  " .. floor((pos - campos).Magnitude * STUDS_TO_M) .. "m" end
                    m.tag.Text = lbl; m.tag.Color = col
                    m.tag.Position = Vector2_new(x, y - 18); m.tag.Transparency = 1; m.tag.Visible = true
                end
            end
        end
    end
    for i = mdrawn + 1, lastMslDrawn do hideMslSlot(mslSlots[i]) end
    lastMslDrawn = mdrawn

    local staffDrawn = 0
    if Config.ModChecker then
        local ml = modTargets
        for i = 1, #ml do
            if staffDrawn >= STAFFPOOL then break end
            local root = ml[i].root
            if root then
                local pos = root.Position
                local top, v1 = WTS(Vector3_new(pos.X, pos.Y + 3, pos.Z))
                local bot, v2 = WTS(Vector3_new(pos.X, pos.Y - 3, pos.Z))
                if v1 and v2 and top and bot then
                    staffDrawn = staffDrawn + 1
                    local s = staffSlots[staffDrawn]
                    local cx = (top.X + bot.X) * 0.5
                    local cy = (top.Y + bot.Y) * 0.5
                    local rad = (bot.Y - top.Y) * 0.5; if rad < 0 then rad = -rad end; if rad < 6 then rad = 6 end
                    s.marker.Position = Vector2_new(floor(cx + 0.5), floor(cy + 0.5))
                    s.marker.Radius = rad; s.marker.Visible = true
                    s.tag.Text = ml[i].role .. "  " .. ml[i].name
                    s.tag.Position = Vector2_new(floor(cx + 0.5), floor(top.Y - 15))
                    s.tag.Visible = true
                end
            end
        end
    end
    for i = staffDrawn + 1, lastStaffDrawn do hideStaffSlot(staffSlots[i]) end
    lastStaffDrawn = staffDrawn

    if Config.ModChecker and #modTargets > 0 then
        local cam = Workspace.CurrentCamera
        local vpx = (cam and cam.ViewportSize.X) or 1920
        local px = vpx - 236
        local n = #modTargets; if n > STAFFPOOL then n = STAFFPOOL end
        staffBg.Position = Vector2_new(px, 12); staffBg.Size = Vector2_new(224, 26 + n * 16); staffBg.Visible = true
        staffTitle.Text = "STAFF IN SERVER (" .. #modTargets .. ")"; staffTitle.Position = Vector2_new(px + 8, 18); staffTitle.Visible = true
        for i = 1, STAFFPOOL do
            local t = modTargets[i]
            if t then
                staffLines[i].Text = t.role .. "  " .. t.name
                staffLines[i].Position = Vector2_new(px + 8, 40 + (i - 1) * 16)
                staffLines[i].Visible = true
            else
                staffLines[i].Visible = false
            end
        end
    else
        staffBg.Visible = false; staffTitle.Visible = false
        for i = 1, STAFFPOOL do staffLines[i].Visible = false end
    end

    if Config.ModChecker and #modTargets > 0 then
        local cam = Workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2_new(1920, 1080)
        local n = #modTargets
        staffPopup.Text = "!!  " .. (n > 1 and (n .. " STAFF") or modTargets[1].role:upper()) .. " IN THE SERVER  !!"
        staffPopup.Position = Vector2_new(vp.X * 0.5, vp.Y * 0.12); staffPopup.Visible = true
    else
        staffPopup.Visible = false
    end

    if Config.Overlay then
        ovrTitle.Text = "BUYCHEAT.ORG"
        ovrLines[1].Text = "FPS       " .. floor(fps)
        ovrLines[2].Text = "Ping      " .. floor(GetPingValue() or 0) .. "ms"
        ovrLines[3].Text = "Vehicles  " .. detected
        ovrLines[4].Text = "On-screen " .. drawn
        ovrLines[5].Text = "Nearest   " .. (nearName and (nearName .. " " .. nearM .. "m") or "-")
    end
end
conn = RS.RenderStepped:Connect(function(dt)
    local ok,err=pcall(originalFrame,dt)
    if not ok then recordError("overlay",err) end
end)

local suppliedAPI=(function()
local NOOP=function() end

                                                                             
                                                                                
local supplied = {jobs={}, entries={}, armour={}, rockets={}, seats={}, vehicles={},
    weaponOwners={}, armourOwners={}, rocketIndex=1, armourIndex=1, aimIndex=1,
    nextRocket=0, accumulator=0, nextActive=0, nextStatus=0, nextBind=0,
    nextRescan=0, signature=nil, active=false, activeRockets={}, lastSeat=nil, lastSeatAt=0,
    binds={}, keys={}, solo=nil, gc=nil, rapidApplied=false, types={}, target=nil,
    moduleCache={},aimSweepPart=nil,aimSweepDistance=nil,aimPart=nil,rocketOriginals={},
    armourOriginals={},armourEnabled=false,armourValue=nil}
local profileControls={
    mtc_enabled="Enabled",mtc_box="Box",mtc_names="Names",mtc_class="Class",mtc_dist="Distance",
    mtc_reload="ReloadStatus",mtc_fade="Fade",mtc_heli="Heli",mtc_occ="OccupiedOnly",mtc_team="TeamCheck",
    mtc_overlay="Overlay",mtc_maxdist="MaxDist",mod_outline="ModOutline",mod_filled="ModFilled",
    mod_engine="ModEngine",mod_ammo="ModAmmo",mod_maxdist="ModMaxDist",misc_grain="HideGrain",
    misc_drone="Drone",misc_missile="Missile",misc_autoreload="AutoReload",misc_modcheck="ModChecker",
    misc_ballistic="Ballistic",misc_autoflare="AutoFlare",kd_drop="KDDrop",
    mtc_atgm="InfiniteATGM",mtc_autocannon="InfiniteAutocannon",mtc_rapid="RapidFire",
    mtc_armour="ArmourOverride",mtc_armour_value="ArmourValue",mtc_solo="MouseAim",
    mtc_seatfree="SeatFree",mtc_instant_start="InstantStartup",mtc_instant_refill="InstantRefill",
    mtc_refill_module="RefillModule",mtc_rescan="AutoRescan",mtc_seatwatch="SeatWatch",mtc_perf_usage="Usage",
    mtc_cursor_style="CursorStyle",mtc_star="CustomCursor",mtc_star_rainbow="CursorRainbow",mtc_star_size="CursorSize",
    mtc_fov="FOVCircle",mtc_fov_radius="FOVRadius",mtc_fov_color_on="FOVColor",mtc_snapline="TargetSnapline",
    mtc_aim_mode="TargetMode",mtc_aim_module="TargetModule",mtc_modaction="ModAction"}
local profileColors={
    mtc_box_col={255,255,255,255},mtc_name_col={255,255,255,255},mtc_class_col={255,180,80,255},
    mtc_dist_col={140,220,255,255},mod_engine_col={255,140,0,.5},mod_ammo_col={255,40,40,.5},
    misc_ball_col={120,255,180,255},mtc_star_color={35,105,255,1},mtc_fov_color={255,255,255,1},
    mtc_snapline_color={255,255,255,1}}
local legacyProfileKeys={armour="ArmourOverride",armourvalue="ArmourValue",atgm="InfiniteATGM",
    autocannon="InfiniteAutocannon",rapid="RapidFire",perfusage="Usage",autorescan="AutoRescan",
    seatwatch="SeatWatch",modcheck="ModChecker",solo="MouseAim",seatfree="SeatFree",
    crosshair="CustomCursor",crosshairsize="CursorSize",rainbow="CursorRainbow",fov="FOVCircle",
    fovsize="FOVRadius",fovcoloron="FOVColor",snapline="TargetSnapline"}
local profileName="default"
local profileList={"default"}
local profileRefresh,saveProfile,loadProfile,resetProfile
local refillNames={"Hull Ammo","HullAmmo","Bustle Ammo","Basket Ammo","Ready Rack","Semi-Ready Rack","M2 ATGM"}
local function ownVehicle(node)
    local folder=Workspace:FindFirstChild("SpawnedVehicles")
    local address=folder and folder.Address
    while node and node.Parent do
        if node.Parent.Address==address then return node end
        node=node.Parent
    end
end
local function operatingTurret()
    local first=game:GetService("ReplicatedFirst")
    local gui=first:FindFirstChild("NewGuiData")
    local gunner=gui and gui:FindFirstChild("Gunner")
    local data=gunner and gunner:FindFirstChild("Data")
    local link=data and data:FindFirstChild("OperatingTurret")
    return link and alive(link.Value) and link.Value or nil
end
local function roleFor(node)
    local name=tostring(node and node.Name or ""):lower()
    for _,role in ipairs({"gunner","loader","driver","copilot","commander","pilot"}) do
        if name:find(role,1,true) then return role end
    end
    return "seat"
end
local function currentSeat(ignoreSettings)
    if not Config.SeatWatch and not ignoreSettings then return nil end
    local turret=operatingTurret()
    if turret then
        local vehicle=ownVehicle(turret)
        if vehicle then return {seated=true,seat=turret,vehicle=vehicle,role="gunner",method="gui-gunner"} end
    end
    local character=LP and LP.Character
    local torso=character and (character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart"))
    if not torso then return nil end
    local best,bestDistance
    for _,entry in ipairs(supplied.seats) do
        local seat=entry.seat
        if alive(seat) and alive(entry.vehicle) then
            local cf,pos=seat.CFrame,torso.Position
            if cf and pos then
                local relative=cf:PointToObjectSpace(pos)
                local size=seat.Size
                if relative and size and math.abs(relative.X)<=size.X*.5+.75
                    and relative.Y>=-.5 and relative.Y<=size.Y*.5+3.5
                    and math.abs(relative.Z)<=size.Z*.5+.75 then
                    local y=relative.Y-(size.Y*.5+1.5)
                    local distance=relative.X*relative.X+y*y+relative.Z*relative.Z
                    if not bestDistance or distance<bestDistance then
                        best,bestDistance={seated=true,seat=seat,vehicle=entry.vehicle,role=roleFor(seat),method="seat-position"},distance
                    end
                end
            end
        end
    end
    return best
end
local function vehicleSignature()
    local out={}
    local folder=Workspace:FindFirstChild("SpawnedVehicles")
    if folder then for _,vehicle in ipairs(folder:GetChildren()) do
        out[#out+1]=tostring(vehicle.Address)..":"..tostring(vehicle.Name)
    end end
    table.sort(out)
    return table.concat(out,"|")
end
local function queueScan()
    local folder=Workspace:FindFirstChild("SpawnedVehicles")
    if not folder then return false end
    supplied.jobs, supplied.entries = {}, {}
    supplied.moduleCache={}
    for _,vehicle in ipairs(folder:GetChildren()) do
        supplied.jobs[#supplied.jobs+1]={vehicle=vehicle,queue={vehicle},head=1,
            entry={vehicle=vehicle,armour={},rockets={},seats={},weapons={},source=nil}}
    end
    supplied.signature=vehicleSignature()
    return true
end
local function ensureSeatTracking()
    local changed=not Config.AutoRescan or not Config.SeatWatch
    Config.AutoRescan,Config.SeatWatch=true,true
    UI.SetValue("mtc_rescan",true)
    UI.SetValue("mtc_seatwatch",true)
    if changed then queueScan() end
end
local function restoreArmourCell(address)
    local saved=supplied.armourOriginals[address]
    if not saved then return end
    local ok,err=pcall(function()
        if alive(saved.cell) and saved.cell.Value==saved.written then
            saved.cell.Value=saved.value
            Runtime.armourRestored=(Runtime.armourRestored or 0)+1
        end
    end)
    if not ok then recordError("armour",err) end
    supplied.armourOriginals[address]=nil
end
local function restoreArmour()
    local addresses={}
    for address in pairs(supplied.armourOriginals) do addresses[#addresses+1]=address end
    for _,address in ipairs(addresses) do restoreArmourCell(address) end
end
local function syncArmour()
    local enabled=Config.ArmourOverride==true
    if enabled~=supplied.armourEnabled then
        supplied.armourEnabled=enabled
        supplied.armourIndex=1
        if enabled then queueScan();supplied.nextRescan=os.clock()+2 else restoreArmour() end
    end
    if Config.ArmourValue~=supplied.armourValue then
        supplied.armourValue=Config.ArmourValue
        supplied.armourIndex=1
    end
    Runtime.armourActive=enabled
    Runtime.armourValue=Config.ArmourValue
end
local function setArmourOverride(value)
    Config.ArmourOverride=value==true
    syncArmour()
end
local function setArmourValue(value)
    assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Invalid armour value")
    Config.ArmourValue=math.clamp(value,0,100)
    syncArmour()
end
local function writeArmour(cell,occupied)
    local ok,err=pcall(function()
        if not cell then return end
        local address=cell.Address
        if not alive(cell) then supplied.armourOriginals[address]=nil;return end
        if supplied.armourOwners[address]==occupied then restoreArmourCell(address);return end
        local value=cell.Value
        local saved=supplied.armourOriginals[address]
        if saved and value~=saved.written then saved.value=value end
        if value~=Config.ArmourValue then
            if not saved then saved={cell=cell,value=value};supplied.armourOriginals[address]=saved end
            cell.Value=Config.ArmourValue
            saved.written=cell.Value
            Runtime.armourWrites=(Runtime.armourWrites or 0)+1
        end
    end)
    if not ok then recordError("armour",err) end
end
local function refreshVehicleScan(now)
    if not (Config.AutoRescan or Config.ArmourOverride) or now<supplied.nextRescan then return end
    supplied.nextRescan=now+2
    if vehicleSignature()~=supplied.signature or Config.ArmourOverride and #supplied.jobs==0 then queueScan() end
end
local function commitScans()
    supplied.armour,supplied.rockets,supplied.seats,supplied.vehicles={}, {}, {}, {}
    supplied.weaponOwners,supplied.armourOwners={},{}
    for _,entry in pairs(supplied.entries) do
        if alive(entry.vehicle) then
            supplied.vehicles[#supplied.vehicles+1]=entry
            for _,cell in ipairs(entry.armour) do
                supplied.armour[#supplied.armour+1]=cell
                supplied.armourOwners[cell.Address]=entry.vehicle.Address
            end
            for _,gun in ipairs(entry.rockets) do
                supplied.rockets[#supplied.rockets+1]=gun
                supplied.weaponOwners[gun.Address]=entry.vehicle.Address
            end
            for _,seat in ipairs(entry.seats) do supplied.seats[#supplied.seats+1]={seat=seat,vehicle=entry.vehicle} end
        end
    end
    Runtime.scannedVehicles=#supplied.vehicles
    Runtime.scanStatus="Tanks Scanned: "..#supplied.vehicles
    Runtime.armourCells=#supplied.armour
end
local function processScans()
    local usage=math.clamp(Config.Usage,1,100)
    local deadline=os.clock()+.0005+usage*.00001
    local count=0
    while #supplied.jobs>0 and count<math.floor(20+usage) do
        local job=supplied.jobs[1]
        local node=job.queue[job.head]
        if not alive(job.vehicle) or not node then
            if alive(job.vehicle) then supplied.entries[job.vehicle.Address]=job.entry end
            table.remove(supplied.jobs,1)
            commitScans()
        else
            job.queue[job.head]=false;job.head+=1
            local entry=job.entry
            if node.Name=="ArmourValue" and numeric(node) then entry.armour[#entry.armour+1]=node end
            if node.Name=="CurrentRockets" and numeric(node) and node.Parent then entry.rockets[#entry.rockets+1]=node.Parent end
            if not entry.source and part(node) then entry.source=node end
            local name=tostring(node.Name):lower()
            if node.ClassName=="Seat" or node.ClassName=="VehicleSeat"
                or name=="seat" or name:find("gunner",1,true) or name:find("driver",1,true)
                or name:find("copilot",1,true) or name:find("pilot",1,true)
                or name:find("commander",1,true) or name:find("loader",1,true) then
                if part(node) and not name:find("passenger",1,true) then entry.seats[#entry.seats+1]=node end
            end
            for _,child in ipairs(node:GetChildren()) do job.queue[#job.queue+1]=child end
            count+=1
        end
        if count>0 and os.clock()>=deadline then break end
    end
end
local function applySolo(value)
    Config.MouseAim=value==true
    if not supplied.solo then supplied.solo={workspace=Workspace:GetAttribute("Solo"),player=LP:GetAttribute("Solo")} end
    pcall(function() Workspace:SetAttribute("Solo",Config.MouseAim) end)
                                                                               
                                                                               
    pcall(function() LP:SetAttribute("Solo",Config.MouseAim) end)
    Runtime.mouseAimPrerequisite=Workspace:GetAttribute("Solo")==Config.MouseAim
end
local function applyRapid()
    if not Config.RapidFire or supplied.rapidApplied then return end
    supplied.gc=supplied.gc or getgc({"RPM"})
    applygc(supplied.gc,{RPM=.01})
    supplied.rapidApplied=true
end
local function cannonTypes()
    local storage=game:GetService("ReplicatedStorage")
    local root=storage:FindFirstChild("PHRST")
    local shells=root and root:FindFirstChild("Shells")
    local modules=shells and shells:FindFirstChild("Modules")
    if modules then for _,node in ipairs(modules:GetChildren()) do
        if node.ClassName=="ModuleScript" then supplied.types[node.Name:upper()]=true end
    end end
end
local function cannonWeapon(gun)
    if supplied.types[tostring(gun.Name):upper()] then return true end
    local typeValue=gun:FindFirstChild("Type")
    return typeValue and typeValue.ClassName=="StringValue" and supplied.types[tostring(typeValue.Value):upper()] or false
end
local function cannonCells(gun)
    local out,seen={},{}
    local function add(cell)
        if numeric(cell) and not seen[cell.Address] then seen[cell.Address]=true;out[#out+1]=cell end
    end
    local folder=gun:FindFirstChild("AmmoLimitFolder")
    if folder then for _,cell in ipairs(folder:GetChildren()) do add(cell) end end
    for _,name in ipairs({"Mag","CurrentAmmo","Ammo","StoredAmmo","ClipAmmo","BeltAmmo","ReserveAmmo"}) do add(gun:FindFirstChild(name)) end
    for _,cell in ipairs(gun:GetDescendants()) do if cell.Name:lower():find("ammo",1,true) then add(cell) end end
    return out
end
local function autocannon()
    local state=currentSeat()
    if not state or state.role~="gunner" then
        if not Config.SeatFree then return false,"Enter the gunner seat first" end
    end
    local cache=getgc("Mag")
    applygc(cache,"Mag",999999)
    local list={}
    if state then list={state.vehicle} elseif Config.SeatFree then
        local folder=Workspace:FindFirstChild("SpawnedVehicles")
        if folder then list=folder:GetChildren() end
    end
    local found=0
    for _,vehicle in ipairs(list) do
        local roots={vehicle}
        local turrets=vehicle:FindFirstChild("Turrets")
        if turrets then roots[#roots+1]=turrets end
        for _,root in ipairs(roots) do for index=1,3 do
            local turret=root:FindFirstChild("Turret"..index)
            local weapons=turret and turret:FindFirstChild("Weapons")
            if weapons then for _,gun in ipairs(weapons:GetChildren()) do
                if cannonWeapon(gun) then
                    pcall(function() gun:SetAttribute("reloading",false) end)
                    pcall(function() gun:SetAttribute("ServerShotsReady",999999) end)
                    for _,cell in ipairs(cannonCells(gun)) do cell.Value=999999 end
                    found+=1
                end
            end end
        end end
    end
    return found>0,found>0 and "Autocannon applied" or "No autocannon weapon was found"
end
local function startEngine()
    local state=currentSeat()
    if not state or (state.role~="driver" and state.role~="pilot") then return false,"Enter a driver or pilot seat first" end
    local events=state.vehicle:FindFirstChild("Events")
    local event=events and events:FindFirstChild("Engine")
    if not event then return false,"This vehicle has no Engine event" end
    if state.role=="pilot" then event:FireServer("start",true) else event:FireServer("start",true,0) end
    return true,"Instant startup sent"
end
local function refillRack()
    local state=currentSeat()
    if not state then return false,"Enter a vehicle seat first" end
    local modules=state.vehicle:FindFirstChild("DamageModules")
    local name=refillNames[Config.RefillModule+1] or refillNames[1]
    local rack=modules and modules:FindFirstChild(name)
    if not rack then return false,name.." was not found" end
    for _,node in ipairs(state.vehicle:GetDescendants()) do
        if node.Name=="Weapons" then for _,gun in ipairs(node:GetChildren()) do
            local sort=gun:FindFirstChild("RackSort")
            if sort then sort:FireServer(rack);return true,"Refilled "..name end
        end end
    end
    return false,"No weapon with RackSort was found"
end
local function bindActive(id,vk,mode)
    local value=UI.GetValue(id)
    if type(value)=="boolean" then return value end
    local pressed=iskeypressed(vk)
    local was=supplied.keys[id]
    supplied.keys[id]=pressed
    if mode=="toggle" then
        if pressed and not was then supplied.binds[id]=not supplied.binds[id] end
        return supplied.binds[id]==true
    end
    return pressed
end
local function pollBinds(now)
    if now<supplied.nextBind then return end
    supplied.nextBind=now+.05
    for _,binding in ipairs({
        {"mtc_instant_start_kb",0x74,"hold","InstantStartup",startEngine},
        {"mtc_instant_refill_kb",0x52,"hold","InstantRefill",refillRack},
        {"mtc_autocannon_kb",0x72,"hold","InfiniteAutocannon",autocannon}}) do
        local active=bindActive(binding[1],binding[2],binding[3])
        local previous=supplied.binds[binding[1].."_pressed"]
        if Config[binding[4]] and active and not previous then
            local ok,message=binding[5]()
            Runtime[binding[4]]=message
            if not ok then pcall(notify,"Thalassar Private",message,3) end
        end
        supplied.binds[binding[1].."_pressed"]=active
    end
    supplied.active=Config.InfiniteATGM and bindActive("mtc_atgm_kb",0x75,"toggle") or false
end
local function rocketWrite(gun)
    if not alive(gun) then return end
    local cell=gun:FindFirstChild("CurrentRockets")
    if not numeric(cell) then return end
                                                                               
                                                                               
                                                        
    local capacity=tonumber(cell:GetAttribute("MAXROCKETS"))
    if capacity and capacity>0 and capacity<10000 and cell.Value~=capacity then
        if not supplied.rocketOriginals[cell.Address] then
            supplied.rocketOriginals[cell.Address]={cell=cell,value=cell.Value,capacity=capacity}
        end
        cell.Value=capacity
    end
end
local function restoreRockets()
    for _,saved in pairs(supplied.rocketOriginals) do
        if alive(saved.cell) and saved.cell.Value==saved.capacity then saved.cell.Value=saved.value end
    end
    supplied.rocketOriginals={}
end
local function suppliedHeartbeat(dt)
    if not running then return end
    syncArmour()
    processScans()
    local now,usage=os.clock(),math.clamp(Config.Usage,1,100)
    if supplied.active and now>=supplied.nextRocket then
        supplied.nextRocket=now+math.max(.02,.055-usage*.00035)
        local list=supplied.activeRockets
        local batch=math.min(#list,math.max(2,math.ceil(2+usage*.04)))
        for _=1,batch do
            if supplied.rocketIndex>#list then supplied.rocketIndex=1 end
            rocketWrite(list[supplied.rocketIndex]);supplied.rocketIndex+=1
        end
    end
    supplied.accumulator+=dt or .016
    if supplied.accumulator<.14-usage*.001 then return end
    supplied.accumulator=0
    local state=currentSeat()
    local liveState=state
    if state then supplied.lastSeat,supplied.lastSeatAt=state,now end
    if supplied.active and not state and now-supplied.lastSeatAt<15 then state=supplied.lastSeat end
    if now>=supplied.nextStatus then
        supplied.nextStatus=now+.55-usage*.004
        Runtime.seat=state and state.role or "None"
    end
    if Config.ArmourOverride and #supplied.armour>0 then
        local batch=math.min(#supplied.armour,math.max(4,math.ceil(4+usage*.08)))
        local occupiedSeat=liveState or currentSeat(true)
        local occupied=occupiedSeat and occupiedSeat.vehicle.Address
        for _=1,batch do
            if supplied.armourIndex>#supplied.armour then supplied.armourIndex=1 end
            local cell=supplied.armour[supplied.armourIndex]
            writeArmour(cell,occupied)
            supplied.armourIndex+=1
        end
    end
    if supplied.active and (state or Config.SeatFree) and now>=supplied.nextActive then
        supplied.nextActive=now+1
        local list={}
        for _,gun in ipairs(supplied.rockets) do
            if alive(gun) and (Config.SeatFree or state and supplied.weaponOwners[gun.Address]==state.vehicle.Address) then
                list[#list+1]=gun;rocketWrite(gun)
            end
        end
        supplied.activeRockets,supplied.rocketIndex=list,1
    elseif not supplied.active then supplied.activeRockets={};restoreRockets() end
end
local fovDraw=drawingNew("Circle")
fovDraw.Filled=false;fovDraw.Thickness=1;fovDraw.NumSides=64;fovDraw.Visible=false
local snapDraw=drawingNew("Line")
snapDraw.Thickness=1;snapDraw.Visible=false
local cursorLines={}
for i=1,12 do local line=drawingNew("Line");line.Thickness=1.4;line.Visible=false;cursorLines[i]=line end
local function suppliedColor(id,default)
    local r,g,b,a=UI.GetValue(id)
    if type(r)=="number" and type(g)=="number" and type(b)=="number" then
        return Color3.new(r/255,g/255,b/255),type(a)=="number" and a/255 or 1
    end
    return default,1
end
local function safeName(name)
    name=tostring(name or profileName):gsub("[^%w _%-]",""):sub(1,64)
    name=name:gsub("^%s+",""):gsub("%s+$","")
    assert(#name>0,"Enter a profile name")
    return name
end
local function profileDirectory()
    if not isfolder("hitech") then makefolder("hitech") end
    if not isfolder("hitech/configs") then makefolder("hitech/configs") end
end
profileRefresh=function()
    profileDirectory()
    local names={}
    for _,path in ipairs(listfiles("hitech/configs")) do
        local name=path:match("([^/\\]+)%.json$")
        if name then names[#names+1]=name end
    end
    table.sort(names)
    if #names==0 then names={"default"} end
    profileList=names
    local picker=supplied.profilePicker
    if picker and picker.Clear and picker.Add then
        picker:Clear()
        for _,name in ipairs(names) do picker:Add(name) end
    end
    return names
end
saveProfile=function(name)
    name=safeName(name)
    profileDirectory()
    local colors={}
    for id,defaults in pairs(profileColors) do
        local r,g,b,a=UI.GetValue(id)
        if type(r)=="number" then colors[id]={r,g,b,a} else
            local fallback=table.clone(defaults)
            if fallback[4] and fallback[4]<=1 then fallback[4]=fallback[4]*255 end
            colors[id]=fallback
        end
    end
    local data={schema=1,name=name,features=table.clone(Config),colors=colors}
    writefile("hitech/configs/"..name..".json",HttpSvc:JSONEncode(data))
    profileName=name
    UI.SetValue("mtc_cfg_name",name)
    profileRefresh()
    if UI.onProfileSaved then UI.onProfileSaved(name) end
    return true,name
end
local function applyProfile(data)
    local config=data.features or data
    if not data.features then
        config=table.clone(data)
        for legacy,key in pairs(legacyProfileKeys) do if data[legacy]~=nil then config[key]=data[legacy] end end
        if data.cursorstyle then config.CursorStyle=data.cursorstyle=="Cat" and 1 or 0 end
        if data.aimmode then config.TargetMode=data.aimmode=="Players" and 1 or data.aimmode=="Both" and 2 or 0 end
        if data.aimmodule then config.TargetModule=data.aimmodule=="Ammo" and 1 or 0 end
        if data.modaction then config.ModAction=data.modaction=="Unload Script" and 1 or 0 end
        local aliases={crosshaircolor="mtc_star_color",fovcolor="mtc_fov_color",snaplinecolor="mtc_snapline_color"}
        data.colors=data.colors or {}
        for key,id in pairs(aliases) do
            local value=data[key]
            if type(value)=="table" and value.r and value.g and value.b then data.colors[id]={value.r,value.g,value.b,value.a or 1} end
        end
    end
    for key,default in pairs(configDefaults) do
        local value=config[key]
        if value~=nil and type(value)==type(default) then Config[key]=value end
    end
    if Config.InstantStartup or Config.InstantRefill
        or not Config.SeatFree and (Config.InfiniteATGM or Config.InfiniteAutocannon) then ensureSeatTracking() end
    for id,key in pairs(profileControls) do UI.SetValue(id,Config[key]) end
    for id,defaults in pairs(profileColors) do
        local savedValues=data.colors and data.colors[id]
        local values=savedValues or defaults
        if type(values)=="table" and type(values[1])=="number" then
            local byteProfile=data.schema==1 and data.features~=nil and savedValues~=nil
            local scale=byteProfile and 255 or (math.max(values[1],values[2] or 0,values[3] or 0)>1 and 255 or 1)
            local alpha=byteProfile and ((values[4] or 255)/255) or (values[4] or 1)
            if not byteProfile and alpha>1 then alpha=alpha/255 end
            UI.SetValue(id,Color3.new(values[1]/scale,(values[2] or 0)/scale,(values[3] or 0)/scale),alpha)
        end
    end
    if Config.HideGrain then refreshGrainAddrs();enforceGrain() else restoreGrain() end
    applySolo(Config.MouseAim)
    syncArmour()
    if Config.RapidFire then applyRapid() end
end
loadProfile=function(name)
    name=safeName(name)
    local path="hitech/configs/"..name..".json"
    assert(isfile(path),"Profile was not found")
    local data=HttpSvc:JSONDecode(readfile(path))
    assert(type(data)=="table","Invalid profile")
    applyProfile(data)
    profileName=name;UI.SetValue("mtc_cfg_name",name)
    if UI.onProfileLoaded then UI.onProfileLoaded(name) end
    return true,name
end
resetProfile=function()
    applyProfile({features=table.clone(configDefaults),colors=profileColors})
    if UI.onProfileReset then UI.onProfileReset() end
    return true
end
local function suppliedRender()
    if not running then return end
    if Config.ModChecker and Config.ModAction==1 and #modTargets>0 then
        if _G.MTC and _G.MTC.stop then _G.MTC.stop() end
        return
    end
    pollBinds(os.clock())
    local nativeMouse=LP:GetMouse()
    local mouse=nativeMouse and type(nativeMouse.X)=="number" and type(nativeMouse.Y)=="number"
        and Vector2.new(nativeMouse.X,nativeMouse.Y) or nil
    local cam=Workspace.CurrentCamera
    local viewport=cam and cam.ViewportSize
    local center=mouse or Vector2.new(viewport and viewport.X*.5 or 960,viewport and viewport.Y*.5 or 540)
    local color,alpha=suppliedColor("mtc_fov_color",Color3.fromRGB(255,255,255))
    fovDraw.Visible=Config.FOVCircle
    if Config.FOVCircle then fovDraw.Position=center;fovDraw.Radius=Config.FOVRadius;fovDraw.Color=Config.FOVColor and color or Color3.fromRGB(255,255,255);fovDraw.Transparency=alpha end
    snapDraw.Visible=false
    if Config.TargetSnapline then
        local best,bestPoint,bestDistance
        local function targetModule(vehicle)
            local key=tostring(vehicle.Address)..":"..Config.TargetModule
            local saved=supplied.moduleCache[key]
            if alive(saved) then return saved end
            local modules=vehicle:FindFirstChild("DamageModules")
            if modules then for _,module in ipairs(modules:GetDescendants()) do
                local name=module.Name:lower():gsub("[%s_%-]","")
                local match=Config.TargetModule==0 and name=="engine"
                    or Config.TargetModule==1 and (name:find("ammo",1,true) or name=="readyrack" or name=="semireadyrack")
                if match then
                    if part(module) then supplied.moduleCache[key]=module;return module end
                    local found,volume
                    for _,node in ipairs(module:GetDescendants()) do
                        if part(node) then
                            local size=node.Size
                            local candidate=size.X*size.Y*size.Z
                            if not volume or candidate>volume then found,volume=node,candidate end
                        end
                    end
                    if found then supplied.moduleCache[key]=found;return found end
                end
            end end
            supplied.moduleCache[key]=nil
        end
        local function consider(target)
            if not alive(target) or not part(target) then return end
            local point,visible=WTS(target.Position)
            if point and visible then
                local x,y=point.X-center.X,point.Y-center.Y
                local distance=math.sqrt(x*x+y*y)
                if distance<=Config.FOVRadius and (not bestDistance or distance<bestDistance) then best,bestPoint,bestDistance=target,point,distance end
            end
        end
        if Config.TargetMode~=1 then
            local count=math.min(#supplied.vehicles,math.max(2,math.ceil(2+Config.Usage*.06)))
            for _=1,count do
                if supplied.aimIndex>#supplied.vehicles then supplied.aimIndex=1 end
                local entry=supplied.vehicles[supplied.aimIndex];supplied.aimIndex+=1
                local target=targetModule(entry.vehicle)
                if alive(target) then
                    local point,visible=WTS(target.Position)
                    if point and visible then
                        local x,y=point.X-center.X,point.Y-center.Y
                        local distance=math.sqrt(x*x+y*y)
                        if distance<=Config.FOVRadius and (not supplied.aimSweepDistance or distance<supplied.aimSweepDistance) then
                            supplied.aimSweepPart,supplied.aimSweepDistance=target,distance
                        end
                    end
                end
                if supplied.aimIndex>#supplied.vehicles then
                    supplied.aimPart=supplied.aimSweepPart
                    supplied.aimSweepPart,supplied.aimSweepDistance=nil,nil
                    supplied.aimIndex=1
                end
            end
            consider(supplied.aimPart)
        end
        if Config.TargetMode~=0 then for _,player in ipairs(Players:GetPlayers()) do
            if player.UserId~=LP.UserId then local ch=player.Character;consider(ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head"))) end
        end end
        supplied.target=best
        if bestPoint then
            local c,a=suppliedColor("mtc_snapline_color",Color3.fromRGB(255,255,255))
            snapDraw.From=center;snapDraw.To=Vector2.new(bestPoint.X,bestPoint.Y);snapDraw.Color=c;snapDraw.Transparency=a;snapDraw.Visible=true
        end
    end
    for _,line in ipairs(cursorLines) do line.Visible=false end
    if Config.CustomCursor and Config.CursorStyle<2 then
        local c,a=suppliedColor("mtc_star_color",Color3.fromRGB(35,105,255))
        if Config.CursorRainbow then c=Color3.fromHSV((os.clock()*.2)%1,1,1) end
        local size=Config.CursorSize
        local points={}
        if Config.CursorStyle==0 then
            for i=0,5 do local angle=math.pi/3*i-math.pi/2;points[#points+1]=Vector2.new(center.X+math.cos(angle)*size,center.Y+math.sin(angle)*size) end
            for i,pair in ipairs({{1,3},{3,5},{5,1},{2,4},{4,6},{6,2}}) do local line=cursorLines[i];line.From=points[pair[1]];line.To=points[pair[2]];line.Color=c;line.Transparency=a;line.Visible=true end
        else
                                                                               
            points={{-1,.2},{-1,-1},{-.45,-.55},{.45,-.55},{1,-1},{1,.2},{.6,.75},{-.6,.75},{-1,.2}}
            for i=1,#points-1 do local line=cursorLines[i];line.From=Vector2.new(center.X+points[i][1]*size,center.Y+points[i][2]*size);line.To=Vector2.new(center.X+points[i+1][1]*size,center.Y+points[i+1][2]*size);line.Color=c;line.Transparency=a;line.Visible=true end
        end
    end
end
cannonTypes()
queueScan()
suppliedConnection=RS.RenderStepped:Connect(function(dt)
    local ok,err=pcall(function() suppliedHeartbeat(dt);suppliedRender() end)
    if not ok then recordError("supplied",err) end
end)
task.spawn(function()
    while running do
        local ok,err=pcall(refreshVehicleScan,os.clock())
        if not ok then recordError("rescan",err);supplied.nextRescan=os.clock()+1 end
        task.wait(.25)
    end
end)
suppliedStop=function()
    if suppliedConnection then pcall(function() suppliedConnection:Disconnect() end) end
    pcall(restoreRockets)
    pcall(restoreArmour)
    if supplied.solo then
        pcall(function() Workspace:SetAttribute("Solo",supplied.solo.workspace) end)
        pcall(function() LP:SetAttribute("Solo",supplied.solo.player) end)
    end
end

local function registerUI(tab)

        local asec=tab:Section("Tank Ammo", "Right")
        asec:Toggle("mtc_atgm", "Infinite ATGMs",Config.InfiniteATGM,function(v) Config.InfiniteATGM=v;if v and not Config.SeatFree then ensureSeatTracking() end;if not v then supplied.active=false end end)
        if asec.Keybind then asec:Keybind("mtc_atgm_kb",117,"toggle") end
        asec:Toggle("mtc_autocannon","Infinite Autocannon",Config.InfiniteAutocannon,function(v) Config.InfiniteAutocannon=v;if v and not Config.SeatFree then ensureSeatTracking() end end)
        asec:Tip("Enabling a seat-scoped ammo feature also enables Auto Rescan and Seat Watcher")
        if asec.Keybind then asec:Keybind("mtc_autocannon_kb",114,"hold") end
        asec:Toggle("mtc_rapid","Rapid Fire",Config.RapidFire,function(v) Config.RapidFire=v;if v then local ok,err=pcall(applyRapid);if not ok then recordError("rapid",err) end end end)
        asec:Tip("Rapid Fire uses the original RPM=0.01 callback and does not reverse")
        local armour=tab:Section("Vehicle Armour","Right")
        armour:Toggle("mtc_armour","Armour Value",Config.ArmourOverride,setArmourOverride)
        armour:SliderFloat("mtc_armour_value","Armour",0,100,Config.ArmourValue,"%.2f",setArmourValue)
        local others=tab:Section("Vehicle Controls","Right")
        others:Toggle("mtc_solo","Mouse Aim eligibility",Config.MouseAim,applySolo)
        others:Tip("Enable before entering the gunner seat, then use the game's H switch or Mouse Aim panel. Eligibility is cached when you enter")
        others:Toggle("mtc_seatfree","Seatwatcher Not Required",Config.SeatFree,function(v) Config.SeatFree=v end)
        others:Toggle("mtc_instant_start","Instant Startup",Config.InstantStartup,function(v) Config.InstantStartup=v;if v then ensureSeatTracking() end end)
        if others.Keybind then others:Keybind("mtc_instant_start_kb",116,"hold") end
        others:Toggle("mtc_instant_refill","Instant Refill",Config.InstantRefill,function(v) Config.InstantRefill=v;if v then ensureSeatTracking() end end)
        others:Tip("Startup and refill enable Auto Rescan and Seat Watcher automatically; the correct vehicle seat is still required")
        if others.Keybind then others:Keybind("mtc_instant_refill_kb",82,"hold") end
        others:Combo("mtc_refill_module","Refill",refillNames,0,function(v) Config.RefillModule=v end)
        local scan=tab:Section("Tank Scanning","Right")
        scan:Toggle("mtc_rescan","Auto Rescan",Config.AutoRescan,function(v)
            if not v and Config.SeatWatch then
                UI.SetValue("mtc_rescan",true)
                pcall(notify,"Thalassar Private","Disable Seat Watcher first",3)
                return
            end
            Config.AutoRescan=v
        end)
        scan:Toggle("mtc_seatwatch","Seat Watcher",Config.SeatWatch,function(v)
            if v and not Config.AutoRescan then
                UI.SetValue("mtc_seatwatch",false)
                pcall(notify,"Thalassar Private","Enable Auto Rescan first",3)
                return
            end
            if not v and not Config.SeatFree and supplied.active then
                UI.SetValue("mtc_seatwatch",true)
                pcall(notify,"Thalassar Private","Disable features using Seat Watcher first",3)
                return
            end
            Config.SeatWatch=v
            if not v then supplied.lastSeat=nil end
        end)
        scan:Tip("Seat Watcher requires Auto Rescan; original crew actions use Seat Watcher")
        scan:SliderInt("mtc_perf_usage","Usage",1,100,Config.Usage,function(v) Config.Usage=v end)
        scan:Button("Rescan - Manual",queueScan)
        scan:Button("Clear Cache",function() supplied.gc=nil;queueScan() end)
        local cross=tab:Section("Crosshair","Right")
        cross:Combo("mtc_cursor_style","Cursor",{"Star of David","Cat","Plus","Dot","Circle","Scope","T","Chevron","Hollow circle","X"},0,function(v) Config.CursorStyle=v end)
        cross:Toggle("mtc_star","Custom Cursor",Config.CustomCursor,function(v) Config.CustomCursor=v end)
        cross:ColorPicker("mtc_star_color",35,105,255,1,NOOP)
        cross:Toggle("mtc_star_rainbow","Rainbow Mode",Config.CursorRainbow,function(v) Config.CursorRainbow=v end)
        cross:SliderInt("mtc_star_size","Crosshair Size",5,30,Config.CursorSize,function(v) Config.CursorSize=v end)
        local target=tab:Section("Target Overlay","Right")
        target:Toggle("mtc_fov","FOV",Config.FOVCircle,function(v) Config.FOVCircle=v end)
        target:SliderFloat("mtc_fov_radius","FOV Size",1,500,Config.FOVRadius,"%.0f",function(v) Config.FOVRadius=v end)
        target:Toggle("mtc_fov_color_on","FOV Color",Config.FOVColor,function(v) Config.FOVColor=v end)
        target:ColorPicker("mtc_fov_color",255,255,255,1,NOOP)
        target:Toggle("mtc_snapline","Snapline",Config.TargetSnapline,function(v) Config.TargetSnapline=v end)
        target:ColorPicker("mtc_snapline_color",255,255,255,1,NOOP)
        target:Combo("mtc_aim_mode","Snap Targets",{"Vehicles","Players","Both"},0,function(v) Config.TargetMode=v end)
        target:Combo("mtc_aim_module","Damage Module",{"Engine","Ammo"},0,function(v) Config.TargetModule=v;supplied.moduleCache={} end)
        target:Combo("mtc_modaction","Staff Action",{"Notify","Unload Script"},0,function(v) Config.ModAction=v end)
        local profiles=tab:Section("Profiles","Right")
        profiles:InputText("mtc_cfg_name","Profile name","default",function(v) profileName=v end)
        supplied.profilePicker=profiles:Combo("mtc_cfg_list","Saved Profiles",profileList,0,function(v)
            local name=profileList[v+1]
            if name then profileName=name;UI.SetValue("mtc_cfg_name",name) end
        end)
        profiles:Button("Save Config",function() local ok,err=pcall(saveProfile,profileName);if not ok then recordError("profile",err) end end)
        profiles:Button("Load Config",function() local ok,err=pcall(loadProfile,profileName);if not ok then recordError("profile",err) end end)
        profiles:Button("Reset Config",function() local ok,err=pcall(resetProfile);if not ok then recordError("profile",err) end end)
        pcall(profileRefresh)

end
return {registerUI=registerUI,rescan=queueScan,startEngine=startEngine,refillRack=refillRack,
    setMouseAim=applySolo,applyAutocannon=autocannon,applyRapid=applyRapid,
    setArmourOverride=setArmourOverride,setArmourValue=setArmourValue,
    vehicleContext=function() return currentSeat(true) end,
    diagnostics=function()
        return {armourCells=#supplied.armour,rocketWeapons=#supplied.rockets,scannedVehicles=#supplied.vehicles,
            pendingScans=#supplied.jobs,atgmActive=supplied.active,activeRocketWeapons=#supplied.activeRockets,
            seat=currentSeat(true),snapTarget=supplied.target,fovVisible=fovDraw.Visible,snapVisible=snapDraw.Visible}
    end,
    saveConfig=saveProfile,loadConfig=loadProfile,resetConfig=resetProfile}
end)()

local function try(f) local ok, e = pcall(f); if not ok then warn("[MTC] widget:", e) end end
local NOOP = function() end

local uiOk, uiErr = pcall(function()
    UI.AddTab("MTC", function(tab)
        local sec = tab:Section("Tank ESP", "Left")
        try(function() sec:Toggle("mtc_enabled", "Tank ESP", Config.Enabled, function(v) Config.Enabled = v end) end)

        try(function() sec:Toggle("mtc_box", "Box ESP", Config.Box, function(v) Config.Box = v end) end)
        try(function() sec:ColorPicker("mtc_box_col", 255, 255, 255, 255, NOOP) end)
        try(function() sec:Toggle("mtc_names", "Names", Config.Names, function(v) Config.Names = v end) end)
        try(function() sec:ColorPicker("mtc_name_col", 255, 255, 255, 255, NOOP) end)
        try(function() sec:Toggle("mtc_class", "Vehicle Class", Config.Class, function(v) Config.Class = v end) end)
        try(function() sec:ColorPicker("mtc_class_col", 255, 180, 80, 255, NOOP) end)
        try(function() sec:Toggle("mtc_dist", "Distance", Config.Distance, function(v) Config.Distance = v end) end)
        try(function() sec:ColorPicker("mtc_dist_col", 140, 220, 255, 255, NOOP) end)
        try(function() sec:Toggle("mtc_reload", "Reload Status", Config.ReloadStatus, function(v) Config.ReloadStatus = v end) end)
        try(function() sec:Toggle("mtc_fade", "Distance Fade", Config.Fade, function(v) Config.Fade = v end) end)
        try(function() sec:Toggle("mtc_heli", "Helicopter ESP", Config.Heli, function(v) Config.Heli = v end) end)
        try(function() sec:Toggle("mtc_occ", "Occupied Only", Config.OccupiedOnly, function(v) Config.OccupiedOnly = v end) end)
        try(function() sec:Toggle("mtc_team", "Team Check", Config.TeamCheck, function(v) Config.TeamCheck = v end) end)
        try(function() sec:Toggle("mtc_overlay", "Info Overlay", Config.Overlay, function(v) Config.Overlay = v end) end)
        try(function() sec:SliderInt("mtc_maxdist", "Max Distance", 0, 4000, Config.MaxDist, function(v) Config.MaxDist = v end) end)

        local msec = tab:Section("Tank Module", "Left")
        try(function() msec:Toggle("mod_outline", "Outline", Config.ModOutline, function(v) Config.ModOutline = v end) end)
        try(function() msec:Toggle("mod_filled", "Filled", Config.ModFilled, function(v) Config.ModFilled = v end) end)

        try(function() msec:Toggle("mod_engine", "Engine", Config.ModEngine, function(v) Config.ModEngine = v end) end)
        try(function() msec:ColorPicker("mod_engine_col", 255, 140, 0, MOD_FILL_A, NOOP) end)
        try(function() msec:Toggle("mod_ammo", "Ammo", Config.ModAmmo, function(v) Config.ModAmmo = v end) end)
        try(function() msec:ColorPicker("mod_ammo_col", 255, 40, 40, MOD_FILL_A, NOOP) end)
        try(function() msec:SliderInt("mod_maxdist", "Module Distance", 0, 4000, Config.ModMaxDist, function(v) Config.ModMaxDist = v end) end)

        local xsec = tab:Section("Misc", "Right")
        try(function() xsec:Toggle("misc_grain", "Hide Drone Grain", Config.HideGrain, function(v)
            Config.HideGrain = v
            if v then refreshGrainAddrs(); enforceGrain() else restoreGrain() end
        end) end)
        try(function() xsec:Toggle("misc_drone", "Drone ESP", Config.Drone, function(v) Config.Drone = v end) end)
        try(function() xsec:Toggle("misc_missile", "Missile ESP", Config.Missile, function(v) Config.Missile = v end) end)
        try(function() xsec:Toggle("misc_autoreload", "Auto Fast Reload", Config.AutoReload, function(v) Config.AutoReload = v end) end)
        try(function() xsec:Toggle("misc_modcheck", "Mod Checker", Config.ModChecker, function(v) Config.ModChecker = v end) end)
        try(function() xsec:Toggle("misc_ballistic", "Ballistic Calc", Config.Ballistic, function(v) Config.Ballistic = v end) end)
        try(function() xsec:ColorPicker("misc_ball_col", 120, 255, 180, 255, NOOP) end)
        try(function() xsec:Toggle("misc_autoflare", "Auto Flare", Config.AutoFlare, function(v) Config.AutoFlare = v end) end)

        suppliedAPI.registerUI(tab)
        local ksec = tab:Section("KD Dropper", "Right")
        try(function() ksec:Toggle("kd_drop", "KD Dropper", Config.KDDrop, function(v) Config.KDDrop = v end) end)
    end)
end)
if not uiOk then pcall(notify, "MTC", "UI failed: " .. tostring(uiErr), 8) end

_G.MTC = {
    version=VERSION, config=Config, status=function() return Runtime end,
    rescan=suppliedAPI.rescan, startEngine=suppliedAPI.startEngine, refillRack=suppliedAPI.refillRack,
    setMouseAim=suppliedAPI.setMouseAim, applyAutocannon=suppliedAPI.applyAutocannon, applyRapid=suppliedAPI.applyRapid,
    setArmourOverride=suppliedAPI.setArmourOverride,setArmourValue=suppliedAPI.setArmourValue,
    vehicleContext=suppliedAPI.vehicleContext,
    diagnostics=function()
        local out=suppliedAPI.diagnostics()
        out.vehicleTargets=#targets;out.vehicleDrawn=lastDrawn;out.moduleDrawn=lastModDrawn
        out.missileTargets=#mslTargets;out.missileDrawn=lastMslDrawn
        out.staffReady=modReady;out.staffTargets=#modTargets;out.staffDrawn=lastStaffDrawn
        out.ballistic=ballResult;out.ballisticVisible=ballTitle.Visible or ballRange.Visible
        out.grainObjects=#grainList;out.overlayVisible=ovrBg.Visible
        out.classificationDraws={}
        for _,slot in ipairs(slots) do
            if slot.cls.Visible then
                local outDraws=out.classificationDraws
                outDraws[#outDraws+1]={vehicle=slot.classTarget,class=slot.cls.Text,
                    faction=slot.classFaction,rgb=slot.classRGB,fishBacking=slot.classBg.Visible,
                    colorSource=slot.classColorSource,teamMarker=slot.classTeamMarker}
            end
        end
        local visible,texts=0,{}
        for _,node in ipairs(drawings) do
            if node.Visible then
                visible+=1
                if type(node.Text)=="string" and #node.Text>0 and #texts<12 then texts[#texts+1]=node.Text end
            end
        end
        out.visibleDrawings=visible;out.visibleText=texts
        return out
    end,
    saveConfig=suppliedAPI.saveConfig,loadConfig=suppliedAPI.loadConfig,resetConfig=suppliedAPI.resetConfig,
    ballistic=function() return ballResult end,
    drawingStats=function() return {allocated=#drawings} end,
    stop=function()
        if not running then return end
        running=false
        if conn then pcall(function() conn:Disconnect() end) end
        if suppliedStop then pcall(suppliedStop) end
        if Config.HideGrain then pcall(restoreGrain) end
        pcall(keyrelease,0x45);pcall(keyrelease,0x47)
        for _,drawing in ipairs(drawings) do pcall(function() drawing:Remove() end) end
        drawings={}
        pcall(function() UI.RemoveTab("MTC") end)
        Runtime.stopped=true
    end,
}
Runtime.uiOK=uiOk
Runtime.ready=uiOk
if not uiOk then recordError("UI",uiErr);_G.MTC.stop() end
print("[Thalassar Private] original scripts combined, uiOK=",uiOk)
return _G.MTC

    end)(glass)
end)
if not success then
    if _G.MTC and _G.MTC ~= previous and type(_G.MTC.stop) == "function" then pcall(_G.MTC.stop) end
    cleanupGlass()
    fail(startupResult)
end
controller = startupResult or _G.MTC
assert(type(controller) == "table" and type(controller.stop) == "function", "Original combined core did not initialize")
if not controller.status().ready then
    pcall(controller.stop)
    cleanupGlass()
    fail("Original combined core could not build its controls")
end
local originalStop = controller.stop
controller.stop = function(...)
    if stopped then return end
    stopped = true
    local ok, message = pcall(originalStop, ...)
    cleanupGlass()
    if not ok then uiError("stop", message) end
end
controller.name, controller.menu = "Thalassar Private", glass
controller.uiVersion, controller.effects = 2, effects
controller.wheelBridge = wheelBridge
controller.crosshairs,controller.worldVisuals=crosshairs,worldVisuals
crosshairs.bindController(controller.config)
glass.AddTab("Presentation",function(tab)
    local worldSection=tab:Section("World",{Group="Visuals"})
    worldVisuals.install(worldSection)
    worldSection:Button("thalassar_world_reset","Restore world visuals",worldVisuals.reset)
    local cursorSection=tab:Section("Crosshair settings",{Group="Targeting"})
    crosshairs.install(cursorSection)
    cursorSection:Button("thalassar_crosshair_reset","Restore crosshair settings",crosshairs.reset)
end)
if previousCrosshairs then crosshairs.import(previousCrosshairs) end
if previousWorld then worldVisuals.import(previousWorld) end
controller.uiFaults = uiFaults
_G.Thalassar = controller
if previousValues then
                                                                                          
    for _,id in ipairs({"mtc_rescan","mtc_seatwatch"}) do
        if previousValues[id]~=nil then
            glass.importValues({[id]=previousValues[id]},true)
            previousValues[id]=nil
        end
    end
    glass.importValues(previousValues,true)
end

local function profileAction(label, callback)
    local ok, message = pcall(callback)
    lastProfileResult = ok and label or tostring(message)
    glass.SetValue("thalassar_profile_status", lastProfileResult)
    if not ok then uiError("profile", message) end
end
controller.saveProfile = function(name)
    profileAction("Profile saved", function()
        controller.saveConfig(name or glass.GetValue("mtc_cfg_name") or "default")
    end)
    return lastProfileResult
end
controller.loadProfile = function(name)
    profileAction("Profile loaded", function()
        controller.loadConfig(name or glass.GetValue("mtc_cfg_name") or "default")
    end)
    return lastProfileResult
end

local profileSection = glass.profileSection or glass.SettingsSection
if not profileSection then
    glass.AddTab("Settings", function(tab) profileSection = tab:Section("Profiles") end)
end
assert(profileSection, "Thalassar settings section missing")
profileSection:Button("thalassar_unload", "Unload script", function() controller.stop() end)
profileSection:Label("thalassar_profile_status", "Config profiles save controls, keybinds, and appearance.")
profileSection:Tip("P opens and closes the menu. Config profiles also save the appearance.")

if previousSection then glass.selectSection(previousSection) end
glass.setVisible(previousVisible~=false)
local firstFrameOK, firstFrameError = pcall(glass.step, 0)
if not firstFrameOK then controller.stop(); fail(firstFrameError) end

renderConnection = game:GetService("RunService").RenderStepped:Connect(function(dt)
    if stopped then return end
    wheelBridge.update()
    local worldOK,worldError=pcall(worldVisuals.step,dt or 1/60)
    if not worldOK then uiError("world visuals",worldError) end
    crosshairs.step(dt or 1/60)
    local ok, message = pcall(glass.step, dt or 1 / 60)
    if not ok then
        uiError("glass UI", message)
                                                                                          
        pcall(glass.setVisible, false)
    end
end)
if builtinUI and type(builtinUI.RemoveTab) == "function" then pcall(builtinUI.RemoveTab, "MTC") end
pcall(notify, "Thalassar Private", "Loaded. P opens the menu.", 4)
print("[Thalassar Private] Original combined core and custom UI loaded")

do
    local app = _G.Thalassar
    assert(app and app.menu, "Thalassar Private did not start")
    app.menu.setVisible(true)
end

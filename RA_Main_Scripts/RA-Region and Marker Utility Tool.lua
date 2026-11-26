-- @description RA - Region and Marker Utility Tool
-- @version 1.0
-- @author RESERVOIR AUDIO / MrBrock, with AI
-- @about Modernization of cfillion's Copy/paste project markers and/or regions v1.1.2. after Region lane addition to reaper.
-- Requires ReaImGui and a REAPER version with ruler lane APIs.

local r = reaper
local SECTION, KEY = 'RA_MarkerRegionClipboard', 'clipboard_v1'
local TITLE = 'RA - Marker & Region Clipboard'
local required = {'ImGui_CreateContext','GetNumRegionsOrMarkers','GetRegionOrMarker',
  'GetRegionOrMarkerInfo_Value','GetSetRegionOrMarkerInfo_String',
  'AddRegionOrMarker','SetRegionOrMarkerInfo_Value','GetSetProjectInfo_String'}
for _, name in ipairs(required) do
  if not r.APIExists(name) then
    r.MB('Missing API: '..name..'\nUpdate REAPER and install/update ReaImGui.', TITLE, 0)
    return
  end
end

-- Length-prefixed text fields: no executable serialization or delimiter collisions.
local function encode(data)
  local out = {}
  local function put(v)
    local s = type(v)=='number' and string.format('%.17g',v) or tostring(v)
    out[#out+1] = #s..':'..s
  end
  put('RA1'); put(#data.lanes); put(#data.entries)
  for _, l in ipairs(data.lanes) do
    put(l.num); put(l.guid); put(l.name); put(l.color); put(l.hidden)
    put(l.locked); put(l.timebase); put(l.kind)
  end
  for _, m in ipairs(data.entries) do
    put(m.region); put(m.start); put(m.finish); put(m.name)
    put(m.id); put(m.color); put(m.hidden); put(m.lane)
  end
  return table.concat(out)
end

local function decode(s)
  local p = 1
  local function get()
    local a,b,n = s:find('^(%d+):',p)
    assert(a, 'Invalid clipboard field')
    n=tonumber(n); p=b+1
    assert(p+n-1<=#s, 'Truncated clipboard')
    local v=s:sub(p,p+n-1); p=p+n; return v
  end
  local function num() return assert(tonumber(get()),'Invalid clipboard number') end
  assert(get()=='RA1','Unsupported clipboard format')
  local nl,nm=num(),num()
  assert(nl>=0 and nm>=0 and nl%1==0 and nm%1==0 and nl+nm<=#s,'Invalid clipboard count')
  local d={lanes={},entries={}}
  for i=1,nl do
    d.lanes[i]={num=num(),guid=get(),name=get(),color=num(),hidden=num(),
      locked=num(),timebase=num(),kind=get()}
  end
  for i=1,nm do
    d.entries[i]={region=num(),start=num(),finish=num(),name=get(),id=num(),
      color=num(),hidden=num(),lane=num()}
  end
  assert(p==#s+1,'Unexpected clipboard data')
  return d
end

local function project() return r.EnumProjects(-1,'') end
local function pi(p,key,value)
  return r.GetSetProjectInfo(p,key,value or 0,value~=nil)
end
local function ps(p,key,value)
  local ok,s=r.GetSetProjectInfo_String(p,key,value or '',value~=nil)
  return ok and s or nil
end
local function lane(p,n)
  local suffix=':'..math.floor(n)
  local guid=ps(p,'RULER_LANE_GUID'..suffix)
  if not guid or guid=='' then return nil end
  return {num=n,guid=guid,name=ps(p,'RULER_LANE_NAME'..suffix) or '',
    color=pi(p,'RULER_LANE_COLOR'..suffix),hidden=pi(p,'RULER_LANE_HIDDEN'..suffix),
    locked=pi(p,'RULER_LANE_LOCKED'..suffix),timebase=pi(p,'RULER_LANE_TIMEBASE'..suffix),
    kind=ps(p,'RULER_LANE_TYPE'..suffix) or ''}
end
local function lanes(p)
  local list,seen={},{}
  -- Probe both boundaries; GUID validity avoids assuming zero/one-based numbering.
  for n=0,math.floor(pi(p,'RULER_LANE_COUNT')) do
    local l=lane(p,n)
    if l and not seen[l.guid] then list[#list+1]=l; seen[l.guid]=true end
  end
  return list
end
local function get(p,m,k) return r.GetRegionOrMarkerInfo_Value(p,m,k) end
local function set(p,m,k,v) return r.SetRegionOrMarkerInfo_Value(p,m,k,v) end
local clipboard={lanes={},entries={}}
local status='Ready'
local raw=r.GetExtState(SECTION,KEY)
if raw~='' then
  local ok,d=pcall(decode,raw)
  if ok then clipboard=d else status='Clipboard unreadable; copy again.' end
end

local function copy(regions_only)
  local p=project()
  local a,b=r.GetSet_LoopTimeRange2(p,false,false,0,0,false)
  local all=a==b
  local d,seen={lanes={},entries={} },{}
  for i=0,r.GetNumRegionsOrMarkers(p)-1 do
    local m=r.GetRegionOrMarker(p,i,'')
    if m then
      local region=get(p,m,'B_ISREGION')~=0
      local start=get(p,m,'D_STARTPOS')
      local finish=region and get(p,m,'D_ENDPOS') or start
      if (region or not regions_only) and (all or (start>=a and finish<=b)) then
        local n=get(p,m,'I_LANENUMBER')
        if not seen[n] then
          local l=assert(lane(p,n),'Cannot read source lane '..n)
          d.lanes[#d.lanes+1]=l; seen[n]=true
        end
        local ok,name=r.GetSetRegionOrMarkerInfo_String(p,m,'P_NAME','',false)
        assert(ok,'Cannot read marker/region name')
        d.entries[#d.entries+1]={region=region and 1 or 0,start=start,finish=finish,
          name=name,id=get(p,m,'I_NUMBER'),color=get(p,m,'I_CUSTOMCOLOR'),
          hidden=get(p,m,'B_HIDDEN'),lane=n}
      end
    end
  end
  table.sort(d.lanes,function(x,y) return x.num<y.num end)
  table.sort(d.entries,function(x,y)
    if x.start~=y.start then return x.start<y.start end
    if x.lane~=y.lane then return x.lane<y.lane end
    if x.region~=y.region then return x.region<y.region end
    return x.id<y.id
  end)
  local encoded=encode(d)
  r.SetExtState(SECTION,KEY,encoded,false)
  assert(r.GetExtState(SECTION,KEY)==encoded,'Clipboard storage verification failed')
  clipboard=d
  status=string.format('Copied %d entries from %d lanes.',#d.entries,#d.lanes)
end

local function compatible(a,b)
  return a.kind=='' or b.kind=='' or a.kind==b.kind
end
local function match(src,dest,used)
  for _,l in ipairs(dest) do
    if l.guid==src.guid and not used[l.guid] then return l end
  end
  local best,score
  for _,l in ipairs(dest) do
    if not used[l.guid] and compatible(src,l) and l.name==src.name then
      if src.name~='' or l.num==src.num then
        local s=(l.color==src.color and 2 or 0)+(l.num==src.num and 1 or 0)
        if not score or s>score then best,score=l,s end
      end
    end
  end
  return best
end

local function create_lane(p,src)
  local before=lanes(p); local old={}
  for _,l in ipairs(before) do old[l.guid]=true end
  local count=pi(p,'RULER_LANE_COUNT')
  -- RULER_LANE_ORDER at the destination index, with value -1, inserts a new lane.
  pi(p,'RULER_LANE_ORDER:'..math.floor(count),-1)
  local after=lanes(p); local new
  for _,l in ipairs(after) do
    if not old[l.guid] then assert(not new,'Unexpected multiple new lanes'); new=l end
  end
  assert(new,'REAPER did not create a ruler lane; no entries pasted into a wrong lane.')
  local suffix=':'..math.floor(new.num)
  assert(ps(p,'RULER_LANE_NAME'..suffix,src.name)~=nil,'Cannot set lane name')
  pi(p,'RULER_LANE_COLOR'..suffix,src.color)
  pi(p,'RULER_LANE_TIMEBASE'..suffix,src.timebase)
  -- Type is only restored if the installed API exposes it.
  if src.kind~='' and new.kind~='' and new.kind~=src.kind then
    ps(p,'RULER_LANE_TYPE'..suffix,src.kind)
  end
  local result=assert(lane(p,new.num),'Cannot read newly created lane')
  assert(result.name==src.name and result.color==src.color,'New lane metadata mismatch')
  assert(compatible(src,result),'New lane type mismatch')
  return result
end

local function paste(relative)
  if #clipboard.entries==0 then status='Clipboard is empty.'; return end
  local p=project()
  local offset=relative and (r.GetCursorPositionEx(p)-clipboard.entries[1].start) or 0
  local mapping,used,created={},{},{}
  local pasted=0
  r.Undo_BeginBlock2(p); r.PreventUIRefresh(1)
  local ok,err=xpcall(function()
    local dest=lanes(p)
    for _,src in ipairs(clipboard.lanes) do
      local target=match(src,dest,used)
      if not target then
        target=create_lane(p,src)
        dest=lanes(p)
        created[#created+1]={guid=target.guid,source=src}
      end
      mapping[src.num]=target.guid; used[target.guid]=true
    end
    -- Resolve once after all insertions, in case lane indices shifted.
    local by_guid={}
    for _,l in ipairs(lanes(p)) do by_guid[l.guid]=l end
    for _,m in ipairs(clipboard.entries) do
      local target=assert(by_guid[mapping[m.lane]],'Destination lane missing')
      local color=math.floor(m.color)
      if color~=0 then color=color|0x1000000 end
      local ptr=assert(r.AddRegionOrMarker(p,m.region==1,m.start+offset,
        m.region==1 and m.finish+offset or 0,m.name,-1,color),'Cannot create marker/region')
      set(p,ptr,'I_LANENUMBER',target.num)
      assert(get(p,ptr,'I_LANENUMBER')==target.num,'Lane assignment failed; undo this paste')
      set(p,ptr,'B_HIDDEN',m.hidden)
      assert(get(p,ptr,'B_HIDDEN')==m.hidden,'Hidden state assignment failed; undo this paste')
      pasted=pasted+1
    end
    -- Lock/hide new lanes only after populating them. Existing settings are untouched.
    for _,c in ipairs(created) do
      local l=assert(by_guid[c.guid]); local suffix=':'..math.floor(l.num)
      pi(p,'RULER_LANE_HIDDEN'..suffix,c.source.hidden)
      pi(p,'RULER_LANE_LOCKED'..suffix,c.source.locked)
      assert(pi(p,'RULER_LANE_HIDDEN'..suffix)==c.source.hidden and
        pi(p,'RULER_LANE_LOCKED'..suffix)==c.source.locked,'New lane state mismatch')
    end
  end,debug.traceback)
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(p,relative and 'RA: Paste markers/regions at cursor' or 'RA: Paste markers/regions',-1)
  r.UpdateArrange()
  if not ok then
    status='Paste interrupted. Undo if project changed.'
    r.MB(err..'\n\nThe paste may be partial. Use Undo before retrying.',TITLE,0)
  else
    status=string.format('Pasted %d entries; created %d lanes.',pasted,#created)
  end
end

-- Region editing is independent of the clipboard.
local function selected_regions(p)
  local list={}
  for i=0,r.GetNumRegionsOrMarkers(p)-1 do
    local m=r.GetRegionOrMarker(p,i,'')
    if m and get(p,m,'B_ISREGION')~=0 and get(p,m,'B_UISEL')~=0 then
      list[#list+1]={ptr=m,start=get(p,m,'D_STARTPOS'),finish=get(p,m,'D_ENDPOS')}
    end
  end
  return list
end

local function edit_regions(p,label,list,fn)
  if #list==0 then return end
  r.Undo_BeginBlock2(p); r.PreventUIRefresh(1)
  local ok,err=xpcall(function()
    for _,m in ipairs(list) do fn(m) end
  end,debug.traceback)
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock2(p,label,-1)
  r.UpdateTimeline(); r.UpdateArrange()
  if not ok then error(err..'\n\nUse Undo before retrying.',0) end
end

local function checked_set(p,m,key,value)
  set(p,m,key,value)
  assert(math.abs(get(p,m,key)-value)<1e-8,'Could not set '..key)
end

local function split_regions()
  local p=project()
  local cursor=r.GetCursorPositionEx(p)
  local selected=selected_regions(p)
  local list={}
  for _,m in ipairs(selected) do
    if cursor>m.start+1e-8 and cursor<m.finish-1e-8 then
      list[#list+1]=m
    end
  end
  if #list==0 then status='No selected region spans the edit cursor.'; return end
  edit_regions(p,'RA: Split selected regions at edit cursor',list,function(m)
    local ptr=m.ptr
    local ok,name=r.GetSetRegionOrMarkerInfo_String(p,ptr,'P_NAME','',false)
    assert(ok,'Cannot read region name')
    local lane_num=get(p,ptr,'I_LANENUMBER')
    local hidden=get(p,ptr,'B_HIDDEN')
    local color=math.floor(get(p,ptr,'I_CUSTOMCOLOR'))
    if color~=0 then color=color|0x1000000 end
    local right=assert(r.AddRegionOrMarker(p,true,cursor,m.finish,name,-1,color),'Cannot create right region')
    checked_set(p,right,'I_LANENUMBER',lane_num)
    checked_set(p,right,'B_HIDDEN',hidden)
    checked_set(p,ptr,'D_ENDPOS',cursor)
    checked_set(p,ptr,'B_UISEL',1)
    checked_set(p,right,'B_UISEL',1)
  end)
  status=string.format('Split %d regions; skipped %d.',#list,#selected-#list)
end

local function resize_regions()
  local p=project()
  local a,b=r.GetSet_LoopTimeRange2(p,false,false,0,0,false)
  if b<=a then status='Create a time selection first.'; return end
  local list={}
  for _,m in ipairs(selected_regions(p)) do
    if math.abs(m.start-a)>1e-8 or math.abs(m.finish-b)>1e-8 then list[#list+1]=m end
  end
  if #list==0 then status='No selected regions need resizing.'; return end
  edit_regions(p,'RA: Resize selected regions to time selection',list,function(m)
    -- Expand first when moving entirely to the right, avoiding inverted bounds.
    if a>=m.finish then
      checked_set(p,m.ptr,'D_ENDPOS',b)
      checked_set(p,m.ptr,'D_STARTPOS',a)
    else
      checked_set(p,m.ptr,'D_STARTPOS',a)
      checked_set(p,m.ptr,'D_ENDPOS',b)
    end
  end)
  status=string.format('Resized %d regions to time selection.',#list)
end

local function run(fn,...)
  local ok,err=xpcall(fn,debug.traceback,...)
  if not ok then status='Operation failed.'; r.MB(err,TITLE,0) end
end

local ctx=r.ImGui_CreateContext(TITLE)
local _,_,section,command=r.get_action_context()
r.SetToggleCommandState(section,command,1); r.RefreshToolbar2(section,command)
r.atexit(function()
  r.SetToggleCommandState(section,command,0); r.RefreshToolbar2(section,command)
end)
-- Terminate this instance when the action is invoked again.
if r.set_action_options then r.set_action_options(1) end
local function loop()
  r.ImGui_SetNextWindowSize(ctx,370,350,r.ImGui_Cond_FirstUseEver())
  local visible,open=r.ImGui_Begin(ctx,TITLE,true)
  if visible then
    r.ImGui_Text(ctx,'COPY')
    if r.ImGui_Button(ctx,'Copy regions in time selection',-1,0) then run(copy,true) end
    if r.ImGui_Button(ctx,'Copy markers & regions in time selection',-1,0) then run(copy,false) end
    r.ImGui_Separator(ctx); r.ImGui_Text(ctx,'PASTE')
    r.ImGui_BeginDisabled(ctx,#clipboard.entries==0)
    if r.ImGui_Button(ctx,'Paste at original position',-1,0) then run(paste,false) end
    if r.ImGui_Button(ctx,'Paste at edit cursor',-1,0) then run(paste,true) end
    r.ImGui_EndDisabled(ctx)
    r.ImGui_Separator(ctx); r.ImGui_Text(ctx,'EDIT REGIONS')
    if r.ImGui_Button(ctx,'Split selected regions at edit cursor',-1,0) then run(split_regions) end
    if r.ImGui_Button(ctx,'Resize selected regions to time selection',-1,0) then run(resize_regions) end
    r.ImGui_Separator(ctx)
    local regions=0
    for _,m in ipairs(clipboard.entries) do regions=regions+m.region end
    r.ImGui_Text(ctx,string.format('Clipboard: %d regions | %d markers | %d lanes',regions,#clipboard.entries-regions,#clipboard.lanes))
    r.ImGui_TextWrapped(ctx,status)
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) end
end
r.defer(loop)


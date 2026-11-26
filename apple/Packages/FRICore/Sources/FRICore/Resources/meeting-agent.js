// Shared by JavaScriptCore and Electron. Only a proposed appointment leaves this module.
(function (root) {
  'use strict';
  const fold = text => text.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/\s+/g, ' ').trim();
  const pad = n => String(n).padStart(2, '0');
  const dayKey = d => [d.getFullYear(), pad(d.getMonth()+1), pad(d.getDate())].join('-');
  const commitment = /\b(chot|xac nhan|dong y|hen gap|hen ban|toi se (den|di|tham gia)|minh se (den|di|tham gia)|minh (di|tham gia)( nhe| nha| luon)?$|ok(?:ay)?|confirmed|count me in|see you|i.ll be there)\b/;
  const uncertain = /[?？]|\b(khong|chua|huy|neu|co le|co the|doi ti|de xem|hay la|thu xem|maybe|might|cancel|unless|not|can.t|won.t|if|tentative)\b/;
  const activities = [
    [/\b(da bong|da banh|da san|football|soccer)\b/, 'Đá bóng'],
    [/\b(ca phe|cafe|coffee)\b/, 'Cà phê'],
    [/\b(an trua|lunch)\b/, 'Ăn trưa'],
    [/\b(an toi|dinner)\b/, 'Ăn tối'],
    [/\b(gap khach hang|gap doi tac|client meeting)\b/, 'Gặp đối tác'],
    [/\b(cuoc goi|goi dien|goi video|video call|call)\b/, 'Cuộc gọi'],
    [/\b(hop|meeting|meetup|trao doi cong viec)\b/, 'Họp'],
    [/\b(an sang|breakfast)\b/, 'Ăn sáng'],
    [/\b(kham benh|di kham|tai kham)\b/, 'Lịch khám'],
    [/\b(phong van|interview)\b/, 'Phỏng vấn'],
    [/\b(di bo|walk)\b/, 'Đi bộ'],
    [/\b(hoc|on thi|study)\b/, 'Học'],
    [/\b(cau long|badminton)\b/, 'Cầu lông']
  ];
  const cancelled = /\b(chua chot|khong (?:di|den|the|tham gia|hop|gap)|huy|doi lich|doi gio|doi ngay|doi sang|doi qua|doi thanh|doi tu|hoan|dung chot|chot don|chot so|khong chot|cancel|postpone|reschedule|won.t)\b/;
  const sensitive = /\b(otp|mat khau|ma xac thuc|ma xac minh|password|passcode|so tai khoan|the tin dung|credit card)\b/;
  const reported = /\b(anh ay|co ay|ho bao|ban ay|sep bao|he said|she said|they said)\b/;
  const acceptance = /^(?:ok(?:ay|ie)?|duoc|dong y|nhat tri|chot|minh di|toi di|count me in|see you|i.ll be there)(?:[,.! ]+(?:nhe|nha|luon|hen gap|cam on|ban|a|minh di|toi di|thu [2-7])|[.! ]+)*$/;
  function details(input, now, preserveAmbiguousTime = false) {
    const text = fold(input);
    let date = null, time = null, timeHint = null;
    const d = new Date(now); d.setHours(12,0,0,0);
    const explicit = text.match(/\b(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?\b/);
    const weekday = text.match(/\b(thu (?:hai|ba|tu|nam|sau|bay|[2-7])|chu nhat|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/);
    if (explicit) {
      const year = explicit[3] ? Number(explicit[3]) : d.getFullYear();
      const x = new Date(year, Number(explicit[2])-1, Number(explicit[1]),12);
      if (x.getMonth()+1 === Number(explicit[2]) && x.getDate() === Number(explicit[1])) date=dayKey(x);
    } else if (/\b(ngay kia|ngay mot|day after tomorrow|mai|tomorrow|hom nay|today|toi nay|chieu nay|sang nay|trua nay)\b/.test(text)) {
      const days = /\b(ngay kia|ngay mot|day after tomorrow)\b/.test(text) ? 2 : /\b(mai|tomorrow)\b/.test(text) ? 1 : 0;
      d.setDate(d.getDate()+days); date=dayKey(d);
    } else if (weekday) {
      const names=['chu nhat','thu hai','thu ba','thu tu','thu nam','thu sau','thu bay'];
      const en=['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
      let w=names.indexOf(weekday[1]);
      if(w<0) w=en.indexOf(weekday[1]);
      if(w<0) w=Number(weekday[1].slice(4))-1;
      let days=(w-d.getDay()+7)%7;
      if (/\btuan sau\b/.test(text)) days=7-(d.getDay()+6)%7+(w+6)%7;
      d.setDate(d.getDate()+days); date=dayKey(d);
    }
    const clock=text.match(/\b(\d{1,2})\s*(?:(?:gio|h|:)\s*(ruoi|\d{1,2})?\s*(sang|chieu|toi|trua|am|pm)?|(am|pm)\b)(?![a-z0-9])/);
    if(clock){
      let hour=Number(clock[1]); const minute=clock[2]==='ruoi'?30:Number(clock[2]||0);
      let period=clock[3]||clock[4];
      if(!period) period=text.match(/\b(sang|chieu|toi|trua)\s+(?:mai\s+|nay\s+)?(?:luc\s+)?\d/)?.[1];
      if(hour<24 && minute<60 && (!period || (hour>=1 && hour<=12))){
        if(['chieu','toi','trua','pm'].includes(period) && hour<12) hour+=12;
        if((period==='am'||period==='sang')&&hour===12)hour=0;
        if(preserveAmbiguousTime && !period && hour>=1 && hour<=12 && !clock[0].includes(':')){
          timeHint=hour+'h'+(minute===0?'':pad(minute));
        } else { time=pad(hour)+':'+pad(minute); }
      }
    }
    const title=activities.find(([pattern])=>pattern.test(text))?.[1]||null;
    const place = input.match(/(?:^|\s)(?:tại|ở|địa điểm|at)\s+([^,.!?\n]{2,60})/iu);
    const location = place?.[1].split(/\s+(?:lúc|vào|ngày|thứ|tối mai|nha|nhé|\d{1,2}(?:h|:))/iu)[0].trim();
    return {title,date,time,...(timeHint ? {timeHint} : {}),...(location && !/^[0-9]/.test(location) ? {location} : {})};
  }
  function recognize(outgoing, previous, now=Date.now()) {
    if(typeof outgoing!=='string'||outgoing.length>480)return null;
    const reply=fold(outgoing);
    if(sensitive.test(reply)||reported.test(reply)||uncertain.test(reply)||cancelled.test(reply)||!commitment.test(reply) && !acceptance.test(reply))return null;
    const own=details(outgoing,now);
    const context=typeof previous==='string'?previous.slice(-480):'';
    if(sensitive.test(fold(context)))return null;
    const other=cancelled.test(fold(context)) || reported.test(fold(context)) ? {} : details(context,now);
    // A bare acknowledgement borrows details only from a concrete invitation.
    const proposal=other.title && (other.date||other.time) || other.date && other.time && /\b(hen|gap|di|meet|see you)\b/.test(fold(context));
    const explicit=own.title || /\b(hen|gap|see you|chot)\b/.test(reply);
    if(!((own.date||own.time) && explicit) && !(proposal && (acceptance.test(reply)||own.title||own.date||own.time)))return null;
    const location=own.location||other.location;
    return {title:own.title||other.title||'Cuộc hẹn',date:own.date||other.date,time:own.time||other.time,...(location?{location}:{})};
  }
  function composerText(input) {
    // Vision may attach the insertion point to a final one-letter question.
    return input.trimEnd().replace(/\bk[ịI/]$/u, 'k').replace(/[|¦]$|([a-zà-ỹ])I$/u, '$1').trimEnd();
  }
  // Informal invitations often omit both the verb and the exact clock time.
  // Keep these location-only questions narrow; incidental mentions of a venue
  // ("xíu trạm có mở cửa k") should not create an appointment.
  const relativeWhen = /\b(?:mot |chut )?(?:xiu|lat|ti|ty|chut)(?: nua)?\b/;
  const shortVenueInvite = /^(?:(?:e|nay|alo)[ ,!]+)?(?:(?:mot |chut )?(?:xiu|lat|ti|ty|chut)(?: nua)?[, ]+)?(?:(?:o|tai|ra|qua|toi|den) )?(?:tram(?: xe buyt| tau)?|thu vien|cang tin|san bong|nha sach)(?: (?:k|ko|khong|hong|hem|hok|hk|nhe|nha|nhi|chu))?[?.!… ]*$/;
  // Invitations in the author's composer may be questions. A time by itself,
  // or an acknowledgement in another person's message, is insufficient here.
  function proposeDraft(input, now=Date.now()) {
    if(typeof input!=='string' || !input.trim() || input.length>480)return null;
    input=composerText(input);
    const text=fold(input);
    if(sensitive.test(text) || reported.test(text) || cancelled.test(text) ||
       /\b(khong muon|dung hen|chua biet|de xem|gio mo cua|mo cua|dong cua|het chuyen|may gio|may h|bao gio|luc nao)\b/.test(text))return null;
    const plan=details(input,now,true);
    const invite=/[?？]\s*$|\b(k|ko|khong|hong|hem|hok|hk|nhe|nha|nhi|chu)[.!… ]*$/.test(text);
    const meetingVerb=/\b(hen|gap|ghe|cung di|di an|di choi|ru|meet)\b/.test(text);
    const place=input.match(/(?:^|\s)(trạm(?: xe buýt| xe buýt nhanh| tàu)?|thư viện|căng tin|sân bóng|nhà sách)(?=\s|[?.!,]|$)/iu)?.[1];
    if(!(plan.title || meetingVerb || plan.location || place))return null;
    if(!invite && !meetingVerb && !commitment.test(text))return null;
    const relative = relativeWhen.test(text);
    const needsTime = !plan.date && !plan.time && !plan.timeHint;
    if(needsTime && !(relative && invite && (shortVenueInvite.test(text) || meetingVerb || plan.title)))return null;
    const result={title:plan.title||'Cuộc hẹn',date:plan.date,time:plan.time};
    if(plan.location||place)result.location=plan.location||place;
    if(plan.timeHint)result.timeHint=plan.timeHint;
    if(needsTime)result.relativeTime='Lát nữa';
    return result;
  }
  function lineKey(line) {
    let hash=2166136261;
    for(const char of fold(line.text))hash=Math.imul(hash^char.charCodeAt(0),16777619);
    return line.side+'|'+hash;
  }
  // Each observation is an ordered list of visible chat lines. Baseline the first
  // frame and require overlap at the bottom before treating a suffix as new.
  class MeetingFrames {
    constructor() { this.recent = new Map(); this.reset(); }
    reset() { this.previous = null; this.lastDraft = null; }
    draft(text, now=Date.now()) {
      const plan=proposeDraft(text,now);
      if(plan){
        const key=lineKey({side:'own',text:composerText(text)});
        const fields=JSON.stringify(plan);
        this.lastDraft={key,fields,at:now,handled:fields===this.lastDraft?.fields && this.lastDraft.handled};
      }
      return plan;
    }
    handleDraft() { if(this.lastDraft)this.lastDraft.handled=true; }
    observe(rows, now=Date.now(), includeSentInvites=false) {
      const lines = rows.filter(r => r && typeof r.text==='string' && r.text.length<=480
        && ['own','other','unknown'].includes(r.side) && r.text.trim()).slice(-24);
      const keys = lines.map(lineKey);
      const before = this.previous;
      this.previous=keys;
      if (!before || !keys.length) return null;
      let overlap=0, end=0;
      for(let n=Math.min(before.length,keys.length);n>0 && !overlap;n--){
        const tail=before.slice(-n);
        for(let j=0;j+n<=keys.length;j++){
          if(tail.every((v,k)=>v===keys[j+k])){overlap=n;end=j+n;}
        }
      }
      if ((!overlap && (before.length || !includeSentInvites)) || end===keys.length) return null;
      for(let i=lines.length-1;i>=end;i--){
        const current=lines[i], previous=lines[i-1];
        if(current.side==='unknown')continue;
        const sameDraft=this.lastDraft && now-this.lastDraft.at<60000 && keys[i]===this.lastDraft.key;
        if(sameDraft && (!includeSentInvites || this.lastDraft.handled))continue;
        const paired=previous && previous.side!=='unknown' && previous.side!==current.side;
        // An incoming reply concerns the owner only when accepting their own proposal.
        if(current.side==='other' && !(paired && acceptance.test(fold(current.text))))continue;
        let result=recognize(current.text,paired?previous.text:'',now);
        if(includeSentInvites && current.side==='own' && (!result || sameDraft)){
          const invitation=proposeDraft(current.text,now);
          if(invitation)result={...invitation, origin:'sentInvitation'};
        }
        if(!result)continue;
        for(const [k,t] of this.recent)if(now-t>600000)this.recent.delete(k);
        const key=JSON.stringify(result);
        if(this.recent.has(key))return null;
        if(this.recent.size>=64)this.recent.delete(this.recent.keys().next().value);
        this.recent.set(key,now);
        return result;
      }
      return null;
    }
  }
  const api={recognize,details,proposeDraft,MeetingFrames};
  if(typeof module==='object' && module.exports)module.exports=api;
  else root.FRIMeetingAgent=api;
})(globalThis);

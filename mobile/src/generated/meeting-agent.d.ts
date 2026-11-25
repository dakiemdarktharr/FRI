declare const rules:{proposeDraft:(text:string,now?:number)=>import('../lib/meeting').MeetingDraft|null;recognize:(text:string,previous:string,now?:number)=>import('../lib/meeting').MeetingDraft|null};
export default rules;

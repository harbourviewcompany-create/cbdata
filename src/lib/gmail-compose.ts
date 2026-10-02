export function gmailComposeUrl(
  email:string|null|undefined,
  subject?:string|null,
  body?:string|null,
) {
  const to=(email??"").trim();
  if(!to) return null;

  const params=new URLSearchParams({
    view:"cm",
    fs:"1",
    to,
  });
  if(subject) params.set("su",subject);
  if(body) params.set("body",body);

  return "https://mail.google.com/mail/?"+params.toString();
}

export function replySubject(subject:string|null|undefined) {
  const value=(subject??"").trim();
  if(!value) return "";
  return /^re:/i.test(value)?value:"Re: "+value;
}

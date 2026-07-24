
const cfg=window.TPG_CONFIG;
const seed=window.TPG_SEED_MENU||[];
const categories=["ຕຳ","ຍຳ","ຕົ້ມ","ທອດ","ຕາມສັ່ງ","ປີ້ງ","ຜັດ","ເຄື່ອງດື່ມ"];
const $=s=>document.querySelector(s);
let client=null, items=[], activeCategory="all";

function configured(){
 return cfg.SUPABASE_URL.startsWith("https://") && !cfg.SUPABASE_URL.includes("PASTE_") &&
        cfg.SUPABASE_ANON_KEY && !cfg.SUPABASE_ANON_KEY.includes("PASTE_");
}
function placeholder(label="Tum Pa Guay"){
 const safe=String(label).replace(/[<>&"]/g,"");
 return "data:image/svg+xml;charset=UTF-8,"+encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="750"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#173e2a"/><stop offset="1" stop-color="#d8ad56"/></linearGradient></defs><rect width="100%" height="100%" fill="url(#g)"/><text x="50%" y="48%" text-anchor="middle" fill="white" font-family="Arial" font-size="54" font-weight="700">${safe}</text><text x="50%" y="58%" text-anchor="middle" fill="#f3ddb0" font-family="Arial" font-size="24">Image coming soon</text></svg>`);
}
function banner(text){
 const el=$("#connectionBanner");el.textContent=text;el.hidden=false;
}
async function loadMenu(){
 if(configured()){
   client=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY);
   const {data,error}=await client.from("menu_items").select("*").order("sort_order",{ascending:true});
   if(!error&&data&&data.length){items=data}
   else{items=seed;banner("กำลังใช้ข้อมูลสำรอง เพราะยังโหลดฐานข้อมูลออนไลน์ไม่ได้")}
 }else{
   items=seed;banner("โหมดตัวอย่าง: ใส่ Supabase URL และ Anon Key ใน config.js เพื่อเปิดระบบออนไลน์")
 }
 renderTabs();renderMenu();
}
function available(){return items.filter(i=>i.available!==false)}
function renderTabs(){
 const wrap=$("#categoryTabs");wrap.innerHTML="";
 const list=["all",...categories];
 list.forEach(cat=>{
  const btn=document.createElement("button");
  const count=cat==="all"?available().length:available().filter(i=>i.category===cat).length;
  btn.textContent=`${cat==="all"?"ທັງໝົດ":cat} (${count})`;
  btn.className=activeCategory===cat?"active":"";
  btn.onclick=()=>{activeCategory=cat;renderTabs();renderMenu()};
  wrap.appendChild(btn);
 })
}
function renderMenu(){
 const q=$("#menuSearch").value.trim().toLowerCase();
 const shown=available().filter(i=>{
   const cat=activeCategory==="all"||i.category===activeCategory;
   const text=`${i.name} ${i.category} ${(i.variants||[]).join(" ")}`.toLowerCase();
   return cat&&text.includes(q)
 });
 $("#menuCount").textContent=available().length;$("#resultCount").textContent=`${shown.length} items`;
 $("#menuGrid").innerHTML="";$("#emptyMenu").hidden=shown.length>0;
 shown.forEach(item=>{
   const card=document.createElement("article");card.className="menu-card";
   card.innerHTML=`<div class="menu-photo"><span class="badge">${item.category}</span><img alt="${item.name}"></div><div class="menu-content"><h3>${item.name}</h3><div class="menu-variants">${(item.variants||[]).join(" / ")}</div><div class="menu-meta"><span class="price">${Number(item.price||0).toLocaleString()} ກີບ</span><span class="status">ມີຂາຍ</span></div></div>`;
   const img=card.querySelector("img");img.onerror=()=>{img.onerror=null;img.src=placeholder(item.name)};img.src=item.image_url||placeholder(item.name);
   card.querySelector(".menu-photo").onclick=()=>openLightbox(img.src,item.name);
   $("#menuGrid").appendChild(card);
 });
}
function openLightbox(src,caption){$("#lightboxImage").src=src;$("#lightboxCaption").textContent=caption;$("#lightbox").hidden=false}
$("#lightboxClose").onclick=()=>$("#lightbox").hidden=true;
$("#lightbox").onclick=e=>{if(e.target.id==="lightbox")$("#lightbox").hidden=true};
$("#menuSearch").oninput=renderMenu;
$("#navToggle").onclick=()=>$("#navLinks").classList.toggle("open");
document.querySelectorAll("#navLinks a").forEach(a=>a.onclick=()=>$("#navLinks").classList.remove("open"));
window.addEventListener("scroll",()=>$("#header").classList.toggle("scrolled",scrollY>30));
window.addEventListener("load",()=>setTimeout(()=>$("#siteLoader").classList.add("hide"),450));
const obs=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting)e.target.classList.add("visible")}),{threshold:.12});
document.querySelectorAll(".reveal").forEach(el=>obs.observe(el));
$("#addressText").textContent=cfg.RESTAURANT.addressLao;

$("#bookingForm").onsubmit=async e=>{
 e.preventDefault();const status=$("#bookingStatus");status.textContent="ກຳລັງສົ່ງ...";
 const booking={customer_name:$("#bookName").value.trim(),phone:$("#bookPhone").value.trim(),booking_date:$("#bookDate").value,booking_time:$("#bookTime").value,guest_count:Number($("#bookGuests").value),note:$("#bookNote").value.trim(),status:"new"};
 let saved=false;
 if(client){const {error}=await client.from("reservations").insert(booking);saved=!error}
 const msg=`ສະບາຍດີ ຮ້ານຕຳປ່າກ້ວຍ
ຂໍຈອງໂຕະ
ຊື່: ${booking.customer_name}
ເບີໂທ: ${booking.phone}
ວັນທີ: ${booking.booking_date}
ເວລາ: ${booking.booking_time}
ຈຳນວນ: ${booking.guest_count} ຄົນ
ໝາຍເຫດ: ${booking.note||"-"}`;
 status.textContent=saved?"ບັນທຶກການຈອງແລ້ວ ແລະ ກຳລັງເປີດ WhatsApp":"ກຳລັງເປີດ WhatsApp";
 window.open(`https://wa.me/${cfg.RESTAURANT.phoneIntl}?text=${encodeURIComponent(msg)}`,"_blank");
};
loadMenu();

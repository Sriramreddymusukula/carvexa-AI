/**
 * Model-level fallback photo galleries for the local/demo catalog.
 * URLs point to the matching CarDekho model gallery image CDN.
 * The live provider gallery still takes precedence; these fill missing images.
 */

const IMAGE_URLS_BY_MODEL = Object.freeze({
  "tata|nexon": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon/11115/1779101151711/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon/9675/1778825266265/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon/9675/1756363999554/front-right-view-120.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon/9675/1756364066883/exterior-image-164.jpg",
  ]),
  "tata|punch": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Punch/13243/1768986024623/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Punch/13254/1768985724266/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Punch/13243/1768985603788/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Punch/13254/1768985724266/rear-left-view-121.jpg",
  ]),
  "tata|harrier": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Harrier/9368/1766125794560/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Harrier/9368/1766125794560/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Harrier/12811/1766125902990/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Harrier/9368/1766125794560/rear-left-view-121.jpg",
  ]),
  "tata|safari": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Safari/12790/1785837912567/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Safari/12790/1785837912567/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Safari/12790/1785837912567/rear-view-119.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Safari/12790/1785837912567/exterior-image-164.jpg",
  ]),
  "tata|tiago": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Tiago/13602/1779960195817/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Tiago/13600/1780994833943/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Tiago/13575/1790159726796/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Tiago/13600/1780994833943/rear-left-view-121.jpg",
  ]),
  "tata|nexon-ev": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon-EV/11024/1755845297648/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon-EV/11024/1753945907283/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon-EV/11024/1753945907283/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Tata/Nexon-EV/11024/1753945907283/rear-left-view-121.jpg",
  ]),
  "hyundai|creta": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Creta/8667/1755765115423/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Creta/11467/1778825201649/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Creta/8667/1751535724464/front-right-view-120.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Creta/11467/1778825201649/exterior-image-164.jpg",
  ]),
  "hyundai|venue": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Venue/12999/1771931633886/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Venue/12694/1763035052031/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Venue/12694/1763035052031/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Venue/12694/1763035052031/rear-left-view-121.jpg",
  ]),
  "hyundai|i20": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/i20/11092/1755774177956/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/i20/11092/1755058597906/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/i20/11092/1755058597906/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/i20/11092/1755058597906/rear-left-view-121.jpg",
  ]),
  "hyundai|verna": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Verna-Facelift/13312/1773040519044/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Verna/13312/1788847979750/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Verna/13312/1788847979750/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Verna/13312/1788847979750/rear-left-view-121.jpg",
  ]),
  "hyundai|alcazar": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Alcazar/9246/1758802404168/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Alcazar/9246/1753867049043/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Alcazar/9246/1753866921818/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Hyundai/Alcazar/9246/1753867049043/rear-left-view-121.jpg",
  ]),
  "kia|seltos": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Seltos/13094/1778328978290/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Seltos/13094/1778328978290/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Seltos/13094/1778328978290/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Seltos/13091/1778825264589/rear-left-view-121.jpg",
  ]),
  "kia|sonet": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sonet/11411/1782132032079/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sonet/11406/1782132114256/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sonet/11411/1782132032079/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sonet/11406/1782132114256/rear-left-view-121.jpg",
  ]),
  "kia|sorento": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sorento/13800/1791192725344/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sorento/13800/1791192725344/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sorento/13800/1791192725344/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Sorento/13800/1791192725344/rear-left-view-121.jpg",
  ]),
  "kia|carens": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Carens/11623/1772787448187/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Carens/11623/1772787448187/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Carens/11623/1772787448187/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Kia/Carens/11623/1772787448187/rear-left-view-121.jpg",
  ]),
  "mahindra|xuv700": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV700/10794/1762509966753/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV700/10794/1762509966753/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV700/10794/1762509966753/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV700/10794/1762509966753/rear-left-view-121.jpg",
  ]),
  "mahindra|scorpio-n": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Scorpio-N/13740/1785926288341/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Scorpio-N/13740/1785926288341/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Scorpio-N/13740/1785926288341/rear-right-side-48.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Scorpio-N/13740/1785926288341/exterior-image-164.jpg",
  ]),
  "mahindra|thar": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Thar/13948/1790589447439/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Thar/13948/1790588115946/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Thar/13948/1790588115946/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/Thar/13948/1790588115946/rear-left-view-121.jpg",
  ]),
  "mahindra|xuv-3xo": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV-3XO/10184/1758199247932/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV-3XO/14105/1792052540764/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV-3XO/14105/1792052540764/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mahindra/XUV-3XO/14105/1792052540764/rear-view-119.jpg",
  ]),
  "toyota|fortuner": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Fortuner/10904/1755846017683/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Fortuner/10904/1755075007369/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Fortuner/10904/1755075007369/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Fortuner/10904/1755075007369/rear-left-view-121.jpg",
  ]),
  "toyota|innova-crysta": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Innova-Crysta/11703/1780562393141/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Innova-Crysta/9613/1780565468505/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Innova-Crysta/9613/1780565468505/exterior-image-164.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Innova-Crysta/9613/1780565468505/grille-97.jpg",
  ]),
  "toyota|urban-cruiser-hyryder": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Hyryder/12837/1776674323818/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Hyryder/10910/1773385497668/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Hyryder/10910/1773385497668/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Hyryder/10910/1773385497668/rear-left-view-121.jpg",
  ]),
  "toyota|glanza": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Glanza/14023/1791969054453/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Glanza/14023/1791973519665/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Glanza/14023/1791973519665/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Toyota/Glanza/14023/1791973519665/rear-view-119.jpg",
  ]),
  "honda|city": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/City/13532/1782194308103/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/City/13532/1780294607751/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/City/13532/1780294607751/rear-view-119.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/City/13532/1780294607751/front-right-view-120.jpg",
  ]),
  "honda|elevate": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Elevate/14055/1791346480435/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Elevate/13931/1791305809948/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Elevate/13931/1791305809948/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Elevate/13931/1791305809948/rear-view-119.jpg",
  ]),
  "honda|amaze": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Amaze/12185/1755764679476/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Amaze/12185/1751089165116/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Amaze/12185/1751089165116/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Honda/Amaze/12185/1751089165116/rear-left-view-121.jpg",
  ]),
  "maruti-suzuki|swift": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Swift/9226/1755777061785/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Swift/9226/1778825394048/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Swift/12028/1774511510786/front-right-view-120.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Swift/12028/1774511736184/exterior-image-164.jpg",
  ]),
  "maruti-suzuki|baleno": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Baleno/12257/1788843598460/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Baleno/12257/1788843598460/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Baleno/12257/1788843598460/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Baleno/12257/1788843598460/rear-left-view-121.jpg",
  ]),
  "maruti-suzuki|brezza": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Brezza/13709/1785846873395/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Brezza/13709/1785413380609/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Brezza/13709/1785413380609/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Brezza/13709/1785413380609/rear-left-view-121.jpg",
  ]),
  "maruti-suzuki|fronx": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/FRONX/9916/1771931850505/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/FRONX/9243/1778825443029/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/FRONX/9243/1756451698043/front-right-view-120.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/FRONX/9243/1756451698043/exterior-image-164.jpg",
  ]),
  "maruti-suzuki|ertiga": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Ertiga/10288/1755776579514/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Ertiga/10288/1778825523598/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Ertiga/10288/1753866143239/front-right-view-120.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Ertiga/10288/1753866143239/exterior-image-164.jpg",
  ]),
  "maruti-suzuki|dzire": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Dzire/12186/1771935643542/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Dzire/11387/1777896846194/rear-left-view-121.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Dzire/11387/1751526167845/front-right-view-120.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Maruti/Dzire/11387/1777896846194/exterior-image-164.jpg",
  ]),
  "volkswagen|virtus": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Virtus/10617/1755846730435/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Virtus/10619/1722405056835/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Virtus/10619/1722405056835/exterior-image-165.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Virtus/10617/1739939470391/exterior-image-166.jpg",
  ]),
  "volkswagen|taigun": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Taigun/13476/1776418515112/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Taigun/13468/1778063618610/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Taigun/13468/1778063618610/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Volkswagen/Taigun/13468/1778063618610/rear-left-view-121.jpg",
  ]),
  "skoda|kushaq": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Kushaq/13279/1779266052419/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Kushaq/13123/1774328649603/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Kushaq/13123/1774328649603/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Kushaq/13123/1774328649603/rear-left-view-121.jpg",
  ]),
  "skoda|slavia": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Slavia/13310/1791271542189/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Slavia/13310/1791271542189/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Slavia/13310/1791271542189/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Skoda/Slavia/13310/1791271542189/rear-left-view-121.jpg",
  ]),
  "mg|hector": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Hector/13125/1783321472876/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Hector/13125/1765801652897/exterior-image-164.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Hector/13125/1765801652897/grille-97.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Hector/13125/1765801652897/wheel-42.jpg",
  ]),
  "mg|astor": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Astor/11413/1762752659543/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Astor/11413/1719383205969/exterior-image-164.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Astor/11413/1742471124078/exterior-image-165.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/MG/Astor/11413/1742471124078/exterior-image-166.jpg",
  ]),
  "bmw|3-series": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/3-Series/10574/1761732994122/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/3-Series/10574/1761732994122/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/3-Series/10574/1761732994122/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/3-Series/10574/1761732994122/rear-left-view-121.jpg",
  ]),
  "bmw|x1": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X1/10065/1787575164062/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X1/10065/1788257372362/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X1/10065/1788257372362/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X1/10065/1788257431755/rear-left-view-121.jpg",
  ]),
  "bmw|x5": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X5/10452/1762779994999/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X5/10490/1689853299825/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X5/10490/1689853299825/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/X5/10490/1689853299825/rear-left-view-121.jpg",
  ]),
  "bmw|m2": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/M2/12205/1762778298430/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/M2/12205/1774956595839/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/M2/12205/1774956595839/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/BMW/M2/12205/1774956595839/rear-left-view-121.jpg",
  ]),
  "mercedes-benz|c-class": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/C-Class/10858/1774342866770/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/C-Class/10858/1774342626058/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/C-Class/10858/1774342626058/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/C-Class/10858/1774342626058/rear-left-view-121.jpg",
  ]),
  "mercedes-benz|glc": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLC/9132/1780561369842/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLC/9132/1780561369842/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLC/9132/1780561369842/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLC/9132/1780561369842/rear-left-view-121.jpg",
  ]),
  "mercedes-benz|gle": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLE/11332/1763535294500/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLE/11332/1779870885644/exterior-image-164.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLE/11927/1724843429681/exterior-image-165.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Mercedes-Benz/GLE/11927/1724843429681/exterior-image-166.jpg",
  ]),
  "audi|q5": Object.freeze([
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Audi/Q5/10556/1757140951323/front-left-side-47.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Audi/Q5/10556/1689594416925/front-view-118.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Audi/Q5/10556/1689594416925/side-view-(left)-90.jpg",
    "https://stimg.cardekho.com/images/carexteriorimages/930x620/Audi/Q5/10556/1689594416925/rear-left-view-121.jpg",
  ]),
});

export const LOCAL_IMAGE_MODEL_COUNT = 46;

export function localImageGallery(brand, model) {
  const identity = `${canonicalBrand(brand)}|${canonicalModel(brand, model)}`;
  const urls = IMAGE_URLS_BY_MODEL[identity];
  if (urls === undefined) return [];
  const title = `${display(brand)} ${display(model)}`;
  return urls.map((url, index) => ({
    url,
    alt: `${title} exterior photo ${index + 1}`,
    category: "exterior",
  }));
}

export function localImageGalleryForTitle(title) {
  const tokens = slug(title).split("-").filter(Boolean);
  if (tokens.length === 0) return [];
  for (const identity of Object.keys(IMAGE_URLS_BY_MODEL)) {
    const [brand, model] = identity.split("|");
    const brandMatches = brand === "maruti-suzuki"
      ? tokens.includes("maruti")
      : brand === "mercedes-benz"
        ? tokens.includes("mercedes")
        : brand.split("-").every((part) => tokens.includes(part));
    const modelMatches = model.split("-").every((part) => tokens.includes(part));
    const hyryderMatches = identity === "toyota|urban-cruiser-hyryder" && tokens.includes("hyryder");
    const mercedesCClassMatches = identity === "mercedes-benz|c-class" &&
      tokens.includes("mercedes") &&
      (tokens.includes("c200") || (tokens.includes("c") && tokens.includes("200")));
    if (brandMatches && (modelMatches || hyryderMatches || mercedesCClassMatches)) {
      return localImageGallery(brand, model);
    }
  }
  return [];
}

function canonicalBrand(value) {
  const brand = slug(value);
  if (brand === "maruti") return "maruti-suzuki";
  if (brand === "mercedes") return "mercedes-benz";
  return brand;
}

function canonicalModel(brand, model) {
  const normalizedBrand = canonicalBrand(brand);
  const normalizedModel = slug(model);
  if (normalizedBrand === "toyota" && normalizedModel === "hyryder") {
    return "urban-cruiser-hyryder";
  }
  return normalizedModel;
}

function slug(value) {
  return String(value ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function display(value) {
  return String(value ?? "").replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim();
}

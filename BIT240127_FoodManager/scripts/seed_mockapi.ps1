param([Parameter(Mandatory=$true)][string]$BaseUrl)
$ErrorActionPreference='Stop'
$BaseUrl=$BaseUrl.TrimEnd('/')
$prefix='BIT240127_'
$categoriesResource='BIT240127_DishCategory'
$dishesResource='BIT240127_Dish'
function Add-Record($resource, $object) {
  $existing = @(Invoke-RestMethod -Uri "$BaseUrl/$resource" -Method Get)
  if ($existing | Where-Object { $_."${prefix}ClientUid" -eq $object."${prefix}ClientUid" }) {
    Write-Host "Skip existing $($object."${prefix}ClientUid")"
    return
  }
  $json = ConvertTo-Json -InputObject $object -Depth 12 -Compress
  Invoke-RestMethod -Uri "$BaseUrl/$resource" -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) | Out-Null
}
$cats = @(
  @{"${prefix}ClientUid"='cat_rice';"${prefix}Name"='Cơm';"${prefix}Description"='Các món cơm'},
  @{"${prefix}ClientUid"='cat_noodles';"${prefix}Name"='Bún, phở';"${prefix}Description"='Món nước'},
  @{"${prefix}ClientUid"='cat_drinks';"${prefix}Name"='Đồ uống';"${prefix}Description"='Thức uống'}
)
foreach ($c in $cats) { Add-Record $categoriesResource $c }
function New-Dish($uid,$name,$price,$minutes,$available,$category,$desc,$photo) {
  return @{"${prefix}ClientUid"=$uid;"${prefix}Name"=$name;"${prefix}Price"=$price;
    "${prefix}PreparationTime"=$minutes;"${prefix}IsAvailable"=$available;
    "${prefix}Description"=$desc;"${prefix}DishCategoryId"=$category;
    "${prefix}DishImage"=@(@{"${prefix}ImageUrl"=$photo;"${prefix}IsThumbnail"=$true})}
}
$photo='https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800'
$dishes=@(
  (New-Dish 'dish_1' 'Cơm gà' 45000 20 $true 'cat_rice' 'Cơm gà thơm ngon' $photo),
  (New-Dish 'dish_2' 'Cơm sườn' 50000 25 $true 'cat_rice' 'Cơm sườn nướng' $photo),
  (New-Dish 'dish_3' 'Phở bò' 55000 15 $true 'cat_noodles' 'Phở bò truyền thống' $photo),
  (New-Dish 'dish_4' 'Bún chả' 45000 20 $false 'cat_noodles' 'Bún chả Hà Nội' $photo),
  (New-Dish 'dish_5' 'Trà đào' 25000 5 $true 'cat_drinks' 'Trà đào mát lạnh' $photo)
)
foreach ($d in $dishes) { Add-Record $dishesResource $d }
Write-Host 'Seed complete: 3 categories, 5 dishes (existing rows skipped).'

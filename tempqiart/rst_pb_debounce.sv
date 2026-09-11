//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// SPDX-FileCopyrightText: Copyright (c) 2022-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
//////////////////////////////////////////////////////////////////////////////////////////////////////////


module rst_pb_debounce  #(  
  parameter                     DEBOUNCE_CNT = 2000000 )
(
    input   logic                 clk,
    input   logic                 pb_rst_in,
    output  logic                 pb_rst_out
);





//put a blank line above


`pragma protect begin_protected
`pragma protect version=1
`pragma protect author="NVIDIA"
`pragma protect author_info="HOLOLINK"
`pragma protect encrypt_agent="Radiant encrypt_hdl"
`pragma protect encrypt_agent_info="Radiant encrypt_hdl Version 1.0"

`pragma protect encoding=(enctype="base64", line_length=64, bytes=256)
`pragma protect key_keyowner="Lattice Semiconductor"
`pragma protect key_keyname="LSCC_RADIANT_2"
`pragma protect key_method="rsa"
`pragma protect key_block
v+19Ci+VgCcE7r73DLRMKOMopNHALQbrKeJQzehRNJa4hFxPkQI7VkvFaa6qRJvY
TxrIqX4AN2wOSJ8FF8tl84UvJsDFVwKiAAacWysvcjW2ZmLqUaDpn3ty3hKjWsif
WEtPEHh3bKDYzJ5fdKyXZ5sn+c1grGmuf4CoFbmk1mbcqLIbH9Vq3noPmQfJAdVo
KOSE/TMixjeVUk6vxvpPMq3+BXvI3p8YEdFwvjZX7pOnYIShrblF10QaC8g5dmEr
MTDfny+NP3Q6IRYnP5CTEcsQlgJBNAJT+tEz3YdIQjUPfQUjIFJZFqRCpccFpAx+
ZxDL3vQFc/Z3mgeATv7kHA==

`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_keyowner="Synopsys"
`pragma protect key_keyname="SNPS-VCS-RSA-1"
`pragma protect key_method="rsa"
`pragma protect key_block
CUjUYOV51tas0pKAJx4KzNOekBYoHwebrJi+Dqaij8Qrn7JE/HcL9JvyM7kBh51j
qwy358eL4wKaroDiGOPyILXRLoolLjeSwRP3lO2Z5fnGu7GXNvqqHVkV4ncrnU8R
0aUwudLUhVSfC0X+KtLasbkTR38oXsiDNmbTIhK1SkI=

`pragma protect encoding=(enctype="base64", line_length=64, bytes=256)
`pragma protect key_keyowner="Intel Corporation"
`pragma protect key_keyname="Intel-FPGA-Quartus-RSA-1"
`pragma protect key_method="rsa"
`pragma protect key_block
wJt4n+kMjz8A8ELxxyRxHWX7H2LtH7OPFPDsDgkb2O5LzQOCl+Z8+OlvH3WqouSU
ius1VOW9pgsD4/8YAfgPZkLEONFH5Qm0ViBjyDDHsYaH/1rZXTWMDPkILYr5sW2R
tONJXW1Fo/DovzxF9DeOoh7xKC4D06DvJ+4b97HjGseQuxqfz1F6yQpJTFufxFzd
fuf/bjSmPxPrqcHDRpMJ/uEqonZho8T3Nm/9WwjCNZCgfumtlVcvBm3L68YRIe4c
wDCR2ljcA0YwP1ceYAO6hjRkhbz1cWKp15K2+SXy0KKKHIPb6rIpYrBiqgGulah+
tipk1epi6aSXKloJdihgAQ==

`pragma protect encoding=(enctype="base64", line_length=64, bytes=256)
`pragma protect key_keyowner="Xilinx"
`pragma protect key_keyname="xilinxt_2019_02"
`pragma protect key_method="rsa"
`pragma protect key_block
I7bKQYDTK3v0yr3CeKkzxd5ANxxCA3SpQl0B67XwKVbYMV0xMUqLITt5MbbLRmqm
7/kaSo5Jcd9pZNinjNhESlZWGwJnZgGnVL08eCJlP8nlEfBvasFqqzCkGzfUoNoy
lxqTvmCuYdCKRd1Y5d/lRznkPaE9nki3IhWcc29fPMv6yyAfIVq7ErJmbVQouQ+5
Utw9nKhnVsChOwvQohzFn4gdNjWNGYPxxTBB5rUtc6Vw5dc4MBmKUjCJPRKwBCJN
I7rCzt/tTMKNX5SY1qHmtxECrxAWA9ZG7qdgAkpydb4vxkGGhS1zjujGq50oQ2as
/mUN3izlIsjfzd3uRgdIFA==

`pragma protect encoding=(enctype="base64", line_length=64, bytes=256)
`pragma protect key_keyowner="Synplicity"
`pragma protect key_keyname="SYNP15_1"
`pragma protect key_method="rsa"
`pragma protect key_block
vZq0JXjZIT1Xgfp97Atc3WhWypF9595BqfZmopE28k/8CicutAN35aY1SBzelior
Kr1Ix87uFJsVy+MFV+uf11ck6H0aJU/1h6fzp1aPUtcahh3b5g23/l8aBnh9ErUv
M7QSfUbREo6ba87jatGc2MpkLZikLpJUn2K9oZo7trZDlQcjNLvDybJwlCPosG3M
epKBuJhT/lACqKdrglG3FXze28S7Bosdbn5dQUQWRFtyYnRkqjAwoHzRD4xgqPjm
zzgR3HxfyUGWR4zqVfptwHpJVieMXUHcFDJdQaXa7HlSKWO9gxDcjknf9Duqr46u
SryY3lLhgadDzj4UYXjBCA==

`pragma protect encoding=(enctype="base64", line_length=64, bytes=256)
`pragma protect key_keyowner="Synplicity"
`pragma protect key_keyname="SYNP05_001"
`pragma protect key_method="rsa"
`pragma protect key_block
krih/Nkd4tvRV2RzF8kghukyXNv9Dq6wFmn5d3fC7XkUyS8E/4u/iquMje9d9pxI
wlM60zdUdN5sJDAEoQ0KXP9ISC4/Ju0qWMKPTcnocAYlQ5I2DIjCEm/dCcumzlEd
qosy7W2OwpOKk7d2xEKGKWF9dshW+d5wdD7hiwdP0tsOZzpstaeRJeuImKcd9yNe
L/B3kb8OmkZsKtnRtkzrLFZw/7qquwn0hcvIjbhzyjhhKLJBNzZlTAcq2h1+sScX
V0mimlSYIGSPu3jK26v3h1lFwEXZG6X4Xqwh06dq2JeVY1Nei2/2TrwPCQs9wJi2
tcc/AOa/AdMR/+rv1BVROg==

`pragma protect encoding=(enctype="base64", line_length=64, bytes=960)
`pragma protect key_keyowner="Microsemi Corporation"
`pragma protect key_keyname="MSC-IP-KEY-RSA"
`pragma protect key_method="rsa"
`pragma protect key_block
Dan+kp2YKWwaB5IgV0Ciu6Pamxlj3yO4/C67VcVq5tTIHjGWsWInhCrz2z1sfryt
qZCq1T4hp+viRig3lbtCchuXitBCUrC3x/Bb05GVF7FuWq+7YvpdTtr8leLAoXjS
9dyW6NCQlPveldraskb3YPV3vrFm/DwhAhNf+V5ZMfWqfYibqBn5zwzyr5n2A1Xr
uLXCr5uTb56pzj0t15HjoKUxqFMt5xLDynPDbqZDT+/xRi9rR1xHyzmKcKz+TeB4
DJkc9FKBCVyExGtfGiiO7Jr4JebEgRSK2A0zSFp8Bc2h6NnFFwdwpQdCFMdD+LH6
ev8U69mdRPesyayhEZem+TZW3fpC/bEGgcyfX6MUSV07RW6YiQRU0wVRaW78vCLM
897ALladgIY4CwtsQC+bwz1TuyKt6f3m3PI0DMe3SIzTubaFo5Zy/rMjmj2grhTf
tDvOixvl0KwuUI/KvHl1kL49sgVStDam2GHGEEtncrB8S0RErGNmlu6VLsvgZlLA
I6dDJM4ZshUGMi+odX1Fu/0g1fdHf8UOhiiWPW+gnZ0w/ZPMNBIHIbX8hHgb8YHS
Bu9Qs1G8q3zr9vShBydMBsdEa18hFcuC89GMjx2AF/RyHSt7RrPtH+wn2cRIrUtd
9AOA7REGl36G7aBp9naN06z4fAJ6BOBxtXWSFcsLTjHvPNXPR7MM7d6pOElKIhQF
4SpYDzCDWcIJtgTLTcnoC9C70TweBb8uacNurYPLZFo5PNJZ+XfoRE18MYXx9MJE
cMfmFPstWnY2lGM9sE9mEa3i+l12lwitYhyjbUto7VEkSFrZCk5c/fb4geUIqW1O
WBQ6jNu7HPlPuR7Dkd3NHVgAfg9xIo19meQMiZ+lfF5ZKSk1mdSzLvYg37ssy+ha
3u17j26YDVas9s27f/KZwZSG3P2aRNEb9/E2+x+/p2GYQ2sHc4ZX6bAYuWJ+I+66
1Nh2Sd3C95Wc63hNhr2ZsfIrjHUlCrzsDnQTSIzxfq2PUFJXwnqO6wFCkjr5FwMf
bR1T/mMq6cGuf4mrevWvuV4LdTFoe2BgoVQYiG97o3WAj7pFOIv047/6GtYA+Qir
7/HZPeRES9/BfzR5TQPWLhiLYgB2WU8wG6zia4TWCUZDe/jOLz4145GwMYlm5VPx
2yqwvvIuZ/dXr7SWJNTFrqzNpr2LSuqYwnYc0o9LRJyZyEb3d23PcGzHro/87o1N
QtHLcWtf8LTKU7jMA8B2xzcCOPvuyLITiSegQ332BZsQUOUE6wfPBVT+cweOcy2v

`pragma protect encoding=(enctype="base64", line_length=64, bytes=128)
`pragma protect key_keyowner="Mentor Graphics Corporation"
`pragma protect key_keyname="MGC-VERIFSIM-RSA-1"
`pragma protect key_method="rsa"
`pragma protect key_block
T3jAidKpPYYP+7ChORFXEYMMqq2LqU5/NU2S7m3eLdkw020w9pQMSgSSepmBdfDm
V0DcjqEqyaFCv0+W7ZwveX07fS3LMmhinAuazSD8J7enimIFECdOdTB//gzCnJew
aWYb51oCJJFA7FEfADQB0gQl7gx20dw07FYum49eLG8=

`pragma protect data_method="aes128-cbc"
`pragma protect encoding=(enctype="base64", line_length=64, bytes=800)
`pragma protect data_block
SuCDGwW+jO+Irvd/MBdAoR7vWZbktPEH4GbAZEzI6tu3ZSki6d0BCQelOm8YKlio
l7ZUV0wlWJy9KNFWZjulxmTEv5ZapuNOeS3pz8JLqIB/nlxgVe6I3HvUexKRRvpe
lyyvzHjXNg66SUIhM9OL2iWnZA11ISzS5QonZy+520LKF7KYiW1tmVgMuLvvenbF
Lz1hBGx5huYuMpHZjfVgfGkfWt2KoPKMB8g63Lhoy/6i3hAr8aOGpDvT6dkPoohz
h/sw74bOP7wtHlM/GStIRrudrg0nZRGN8MRqt+t3DwkLXkUkQ7wR3cUpy7E0Y+z9
EAEpkObzwbw8+tAr8nGeRkUrgL+GRajiPUCdPrEp28QyneMB8PhRBxLup4cAkEeq
9MuRlTrfXrdeSKMtG2c7gpEyED/zvTHNhFg8k2kU/SiVQtdCp2S9IZPT8QHgjWLS
n7ajozt17Zp5GrI5QnIJI/L3tHguiS/96makwbmWTjBE3prETip9sEsW0a5jpVeN
sBm/9zXQuetig5fnHEPEt2VUafOMa7dODWAB6mR9BIYGZRo/sDFTmoSx4enajBV9
uwgLhpE/+p2SyvFS6CiWYFyU/qZ7+UdlsHIF/lG18SGMEj23zXGCs7pkgCOYbrW8
ECV4b/Hu+lA0xGrx2UwLWBZkoNMhFHyQmmVaZ0gAA8uIgvThMeMtcJP8Bu9sINvY
Zp8AbCFV4vs9XpagnAbKXodemLZPOoiObto8L6CAyqXVTFBGu7mq4Olz86QupHhX
6Bjdx2Fg3Z6td2cMRTbyyK71T6z24ummA20jOaw+gpxxA1waqEwmTlN/Q1P3Z/73
yX3kFB+IeFoelVfuvu5dNLwcVDNwvOrPGrQGsC0V+DXHLVOwDJoqqrsd7NrXgMq7
rXFtUPytTQIzbHoe1c0wuCwZE9RonhON2gjqmsrnIXEQGHlZhvEtuJ/6/h4FnNbY
CXuYBtOo0l9gKh0whVgyEU0rtA0siYWm6NUuX5G4roUzI/dA/v3lK30kv2cLItOM
VDEmPD87S4Iw0MX+LTqYQ8XAR5JJh5qwn7xT7Sm+5lg=

`pragma protect end_protected

endmodule
    
# ==============================================================================
# LMEPISOWIFI USER PROFILES & SCHEDULERS SCRIPT (v7 Optimized)
# ==============================================================================
:local ntpAlreadySet false;
:do {
    :local curServers [/system ntp client get servers];
    :if ($curServers = "ntp.pagasa.dost.gov.ph,0.asia.pool.ntp.org") do={
        :set ntpAlreadySet true;
    }
} on-error={};

:if ($ntpAlreadySet = false) do={
    :do {
        /system ntp client set enabled=yes servers=ntp.pagasa.dost.gov.ph,0.asia.pool.ntp.org
    } on-error={ }
}
:log info "successfully passed ntp";
/system scheduler

# ==========================================
# Schedulers
# ==========================================

# --- Uptime Backup (Optimized Session Backup) ---
:if ([:len [find name="uptime backup"]] = 0) do={
    add name="uptime backup" interval=5m start-time=startup policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
        :local hsuser;
        :local schid;
        :foreach i in=[/ip hotspot active find] do={
            :set hsuser [/ip hotspot active get $i user];
            :set schid [/system scheduler find name=$hsuser];
            :if ([:len $schid] > 0) do={
                /system scheduler set $schid comment=("temp " . [/ip hotspot active get $i session-time-left]);
            }
        }
    }
} else={
    set [find name="uptime backup"] interval=5m on-event={
        :local hsuser;
        :local schid;
        :foreach i in=[/ip hotspot active find] do={
            :set hsuser [/ip hotspot active get $i user];
            :set schid [/system scheduler find name=$hsuser];
            :if ([:len $schid] > 0) do={
                /system scheduler set $schid comment=("temp " . [/ip hotspot active get $i session-time-left]);
            }
        }
    }
}
:log info "successfully passed uptime backup";
# --- Uptime Restore (Optimized Session Restore) ---
:if ([:len [find name="uptime restore"]] = 0) do={
    add name="uptime restore" start-time=startup policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
        :local schuser;
        :local timeleft;
        :local userid;
        :foreach i in=[/system scheduler find] do={
            :set timeleft [:tostr [/system scheduler get $i comment]];
            :if ($timeleft ~ "^temp ") do={
                :set schuser [/system scheduler get $i name];
                :set userid [/ip hotspot user find name=$schuser];
                :if ([:len $userid] > 0) do={
                    /ip hotspot user reset-counters $userid;
                    /ip hotspot user set $userid limit-uptime=[:pick $timeleft 5 [:len $timeleft]];
                    /system scheduler set $i comment="";
                } else={
                    /system scheduler remove $i;
                }
            }
        }
    }
} else={
    set [find name="uptime restore"] on-event={
        :local schuser;
        :local timeleft;
        :local userid;
        :foreach i in=[/system scheduler find] do={
            :set timeleft [:tostr [/system scheduler get $i comment]];
            :if ($timeleft ~ "^temp ") do={
                :set schuser [/system scheduler get $i name];
                :set userid [/ip hotspot user find name=$schuser];
                :if ([:len $userid] > 0) do={
                    /ip hotspot user reset-counters $userid;
                    /ip hotspot user set $userid limit-uptime=[:pick $timeleft 5 [:len $timeleft]];
                    /system scheduler set $i comment="";
                } else={
                    /system scheduler remove $i;
                }
            }
        }
    }
}

# --- Reset Daily Income ---
:if ([:len [find name="Reset Daily Income"]] = 0) do={
    add name="Reset Daily Income" interval=6h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentday [:pick $currentDate 8 10];
            :local schID [/system scheduler find name="Reset Daily Income"];
            :local incID [/system script find name="todayincome"];
            :if ([:len $schID] > 0 && [:len $incID] > 0) do={
                :local schedulerComment [/system scheduler get $schID comment];
                :if ($schedulerComment != $currentday) do={
                    :local todayIncomeSource [/system script get $incID source];
                    /system script set $incID source="0";
                    /system scheduler set $schID comment="$currentday";
                    :if ($todayIncomeSource != "0" && [:len $todayIncomeSource] > 0) do={
                        :local message ("The%20income%20today%20is:%20" . $todayIncomeSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetdaily: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetdaily: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
} else={
    set [find name="Reset Daily Income"] interval=6h on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentday [:pick $currentDate 8 10];
            :local schID [/system scheduler find name="Reset Daily Income"];
            :local incID [/system script find name="todayincome"];
            :if ([:len $schID] > 0 && [:len $incID] > 0) do={
                :local schedulerComment [/system scheduler get $schID comment];
                :if ($schedulerComment != $currentday) do={
                    :local todayIncomeSource [/system script get $incID source];
                    /system script set $incID source="0";
                    /system scheduler set $schID comment="$currentday";
                    :if ($todayIncomeSource != "0" && [:len $todayIncomeSource] > 0) do={
                        :local message ("The%20income%20today%20is:%20" . $todayIncomeSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetdaily: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetdaily: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
}

# --- Reset Max Active Users ---
:if ([:len [find name="reset maxactiveusers"]] = 0) do={
    add name="reset maxactiveusers" interval=6h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentday [:pick $currentDate 8 10];
            :local schID [/system scheduler find name="reset maxactiveusers"];
            :local scrID [/system script find name="maxactiveusers"];
            :if ([:len $schID] > 0 && [:len $scrID] > 0) do={
                :local schedulerComment [/system scheduler get $schID comment];
                :if ($schedulerComment != $currentday) do={
                    :local currentSource [/system script get $scrID source];
                    /system script set $scrID source="0";
                    /system scheduler set $schID comment="$currentday";
                    :if ($currentSource != "0" && [:len $currentSource] > 0) do={
                        :local message ("The%20top%20active%20users%20for%20today%20is:%20" . $currentSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetmax: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetmax: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
} else={
    set [find name="reset maxactiveusers"] interval=6h on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentday [:pick $currentDate 8 10];
            :local schID [/system scheduler find name="reset maxactiveusers"];
            :local scrID [/system script find name="maxactiveusers"];
            :if ([:len $schID] > 0 && [:len $scrID] > 0) do={
                :local schedulerComment [/system scheduler get $schID comment];
                :if ($schedulerComment != $currentday) do={
                    :local currentSource [/system script get $scrID source];
                    /system script set $scrID source="0";
                    /system scheduler set $schID comment="$currentday";
                    :if ($currentSource != "0" && [:len $currentSource] > 0) do={
                        :local message ("The%20top%20active%20users%20for%20today%20is:%20" . $currentSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetmax: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetmax: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
}

# --- Reset Monthly ---
:if ([:len [find name="resetmonthly"]] = 0) do={
    add name="resetmonthly" interval=6h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentMonth [:pick $currentDate 5 7];
            :local schID [/system scheduler find name="resetmonthly"];
            :local incID [/system script find name="monthlyincome"];
            :if ([:len $schID] > 0 && [:len $incID] > 0) do={
                :local storedMonth [/system scheduler get $schID comment];
                :if ($storedMonth != $currentMonth) do={
                    :local monthlyIncomeSource [/system script get $incID source];
                    /system script set $incID source="0";
                    /system scheduler set $schID comment="$currentMonth";
                    :if ($monthlyIncomeSource != "0" && [:len $monthlyIncomeSource] > 0) do={
                        :local message ("The%20income%20for%20this%20month%20is:%20" . $monthlyIncomeSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetmonthly: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetmonthly: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
} else={
    set [find name="resetmonthly"] interval=6h on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentMonth [:pick $currentDate 5 7];
            :local schID [/system scheduler find name="resetmonthly"];
            :local incID [/system script find name="monthlyincome"];
            :if ([:len $schID] > 0 && [:len $incID] > 0) do={
                :local storedMonth [/system scheduler get $schID comment];
                :if ($storedMonth != $currentMonth) do={
                    :local monthlyIncomeSource [/system script get $incID source];
                    /system script set $incID source="0";
                    /system scheduler set $schID comment="$currentMonth";
                    :if ($monthlyIncomeSource != "0" && [:len $monthlyIncomeSource] > 0) do={
                        :local message ("The%20income%20for%20this%20month%20is:%20" . $monthlyIncomeSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetmonthly: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetmonthly: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
}

# --- Auto Restart ---
:if ([:len [find name="autorestart"]] = 0) do={
    add name="autorestart" interval=1d start-time=03:00:00 on-event="/system reboot" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon
} else={
    set [find name="autorestart"] interval=1d on-event="/system reboot"
}

# --- Reset Yearly ---
:foreach i in=[find where name~"yearly" and name!="reset yearly"] do={ set $i name="reset yearly"; :log info "renamed reset yearly income scheduler" }
:if ([:len [find name="reset yearly"]] = 0) do={
    add name="reset yearly" interval=6h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentyear [:pick $currentDate 0 4];
            :local schID [/system scheduler find name="reset yearly"];
            :local incID [/system script find name="yearlyincome"];
            :if ([:len $schID] > 0 && [:len $incID] > 0) do={
                :local schedulerComment [/system scheduler get $schID comment];
                :if ($schedulerComment != $currentyear) do={
                    :local yearlyIncomeSource [/system script get $incID source];
                    /system script set $incID source="0";
                    /system scheduler set $schID comment="$currentyear";
                    :if ($yearlyIncomeSource != "0" && [:len $yearlyIncomeSource] > 0) do={
                        :local message ("The%20income%20for%20this%20year%20is:%20" . $yearlyIncomeSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetyearly: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetyearly: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
} else={
    set [find name="reset yearly"] interval=6h on-event={
        :local sntpStatus "unknown";
        :do { :set sntpStatus [/system ntp client get status]; } on-error={};
        :if ($sntpStatus = "synchronized") do={
            :local currentDate [/system clock get date];
            :local currentyear [:pick $currentDate 0 4];
            :local schID [/system scheduler find name="reset yearly"];
            :local incID [/system script find name="yearlyincome"];
            :if ([:len $schID] > 0 && [:len $incID] > 0) do={
                :local schedulerComment [/system scheduler get $schID comment];
                :if ($schedulerComment != $currentyear) do={
                    :local yearlyIncomeSource [/system script get $incID source];
                    /system script set $incID source="0";
                    /system scheduler set $schID comment="$currentyear";
                    :if ($yearlyIncomeSource != "0" && [:len $yearlyIncomeSource] > 0) do={
                        :local message ("The%20income%20for%20this%20year%20is:%20" . $yearlyIncomeSource);
                        :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
                        :if ($isTelegram = 1) do={
                            :local iTBotToken [/system script get [find name="bottoken"] source];
                            :local iTGrChatID [/system script get [find name="chatid"] source];
                            :do { /tool fetch url=("https://api.telegram.org/bot" . $iTBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $iTGrChatID . "&text=" . $message) output=none; } on-error={ :log warning "resetyearly: Telegram failed"; }
                        }
                        :delay 1s;
                        :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
                        :if ($isDiscord = 1) do={
                            :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
                            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "%60%60%60" . $message . "%60%60%60%0A** **") mode=https output=none; } on-error={ :log warning "resetyearly: Discord failed"; }
                        }
                    }
                }
            }
        }
    }
}

# ==========================================
# HOTSPOT USER PROFILE
# ==========================================

/ip hotspot user profile
set [ find default=yes ] add-mac-cookie=no keepalive-timeout=3m name=\
    autospeedlimit on-login="# ===============================================\
    =============\
    \n# Hotspot Login Script (Optimized for RouterOS v7)\
    \n# ============================================================\
    \n\
    \n# --- Clock ---\
    \n:local date [/system clock get date];\
    \n:local time [/system clock get time];\
    \n\
    \n# --- Interface Throughput ---\
    \n:local ifName \"ether1\";\
    \n:local rxBps; :local txBps;\
    \n/interface monitor-traffic \$ifName once do={\
    \n    :set rxBps \$\"rx-bits-per-second\";\
    \n    :set txBps \$\"tx-bits-per-second\";\
    \n}\
    \n:local rxKbps (\$rxBps / 1000);\
    \n:local txKbps (\$txBps / 1000);\
    \n\
    \n:local rxStr \"\";\
    \n:if (\$rxKbps >= 1000) do={\
    \n    :set rxStr ((\$rxKbps / 1000) . \".\" . ((\$rxKbps % 1000) / 100) . \
    \" Mbps\");\
    \n} else={\
    \n    :set rxStr (\"\$rxKbps Kbps\");\
    \n}\
    \n:local txStr \"\";\
    \n:if (\$txKbps >= 1000) do={\
    \n    :set txStr ((\$txKbps / 1000) . \".\" . ((\$txKbps % 1000) / 100) . \
    \" Mbps\");\
    \n} else={\
    \n    :set txStr (\"\$txKbps Kbps\");\
    \n}\
    \n:local queueRate (\"\$rxStr | \$txStr\");\
    \n\
    \n# --- MAC / Address ---\
    \n:local mac    \$\"mac-address\";\
    \n:local addr   \$\"address\";\
    \n:local macNoCol (\"\$[:pick \$mac 0 2]\$[:pick \$mac 3 5]\$[:pick \$mac \
    6 8]\$[:pick \$mac 9 11]\$[:pick \$mac 12 14]\$[:pick \$mac 15 17]\");\
    \n\
    \n# --- Device Name (v7 Safe) ---\
    \n:local deviceName \"N/A\";\
    \n:local dLease [/ip dhcp-server lease find mac-address=\$mac];\
    \n:if ([:len \$dLease] > 0) do={\
    \n    :local hostName [/ip dhcp-server lease get \$dLease host-name];\
    \n    :if ([:len \$hostName] > 0) do={ :set deviceName \$hostName; }\
    \n}\
    \n\
    \n# --- Hotspot User (single fetch) ---\
    \n:local uID [/ip hotspot user find name=\$user];\
    \n:local limit    [/ip hotspot user get \$uID limit-uptime];\
    \n:local uptime   [/ip hotspot user get \$uID uptime];\
    \n:local com      [/ip hotspot user get \$uID comment];\
    \n:local aUsrNote [:toarray \$com];\
    \n:local iSaleAmt [:tonum (\$aUsrNote->1)];\
    \n\
    \n:local totaltime \$limit;\
    \n:local remainingt (\$limit - \$uptime);\
    \n:local totaluptime (\$limit - \$remainingt);\
    \n:local validity \"\";\
    \n\
    \n# --- System Resources ---\
    \n:local cpuusage [/system resource get cpu-load];\
    \n:local freeRam  [/system resource get free-memory];\
    \n:local ramMB    (\$freeRam / 1048576);\
    \n:local ramdecimal ((\$freeRam % 1048576) / 104858);\
    \n\
    \n# --- Active User Count ---\
    \n:local uactive [/ip hotspot active print count-only];\
    \n\
    \n# --- Notification Config ---\
    \n:local hotspotFolder \"hotspot\";\
    \n:local isTelegram  [:tonum [/system script get [find name=\"enabletelegr\
    am\"] source]];\
    \n:local iTBotToken  [/system script get [find name=\"bottoken\"] source];\
    \n:local iTGrChatID  [/system script get [find name=\"chatid\"] source];\
    \n:local isDiscord   [:tonum [/system script get [find name=\"enablediscor\
    d\"] source]];\
    \n:local iDiscordWebhook [/system script get [find name=\"discordwebhook\"\
    ] source];\
    \n\
    \n# --- Sales Tracking ---\
    \n:local todaysales  [:tonum [/system script get [find name=\"todayincome\
    \"] source]];\
    \n:local mnthlysales [:tonum [/system script get [find name=\"monthlyincom\
    e\"] source]];\
    \n:local yearlysales [:tonum [/system script get [find name=\"yearlyincome\
    \"] source]];\
    \n:local iDailySales (\$iSaleAmt + \$todaysales);\
    \n:local iMonthSales (\$iSaleAmt + \$mnthlysales);\
    \n:local iYearSales  (\$iSaleAmt + \$yearlysales);\
    \n\
    \n# --- Update Sales (only if this is a new purchase, not a resume) ---\
    \n:if ([:len \$com] > 0) do={\
    \n    /system script set [find name=\"todayincome\"] source=\"\$iDailySale\
    s\";\
    \n    /system script set [find name=\"monthlyincome\"] source=\"\$iMonthSa\
    les\";\
    \n    /system script set [find name=\"yearlyincome\"] source=\"\$iYearSale\
    s\";\
    \n    :set validity [:pick \$com 0 [:find \$com \",\"]];\
    \n}\
    \n\
    \n# --- Resume Notification (comment was empty = resuming session) ---\
    \n:if ([:len \$com] = 0) do={\
    \n    :local rtimeMessage (\"\$user%20resumed%20time,%20remaining%20time%2\
    0is%20\$remainingt%0AActive%20Users:%20\$uactive\");\
    \n    :if (\$isTelegram = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/s\
    endMessage\" \\\
    \n                http-method=post \\\
    \n                http-data=\"chat_id=\$iTGrChatID&text=\$rtimeMessage\" \
    \\\
    \n                output=none;\
    \n        } on-error={ :log error \"Telegram resume notification failed.\"\
    ; }\
    \n    }\
    \n    :if (\$isDiscord = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\$iDiscordWebhook http-method=post \\\
    \n                http-data=(\"content=\" . \"```\$rtimeMessage```%0A** **\
    \") \\\
    \n                mode=https output=none;\
    \n        } on-error={ :log error \"Discord resume notification failed.\";\
    \_}\
    \n    }\
    \n}\
    \n\
    \n# --- Fix 0m validity (NodeMCU failure fallback) ---\
    \n:if (\$validity = \"0m\") do={\
    \n    :local vendorIp \"10.0.0.5\";\
    \n    :local cachedRates [/system script get [find name=\"cachedrates\"] s\
    ource];\
    \n    :local foundValidity \"\";\
    \n    :local freshRates \"\";\
    \n    :local minutesCache \"\";\
    \n\
    \n    :do {\
    \n        :set freshRates ([/tool fetch url=(\"http://10.0.0.5/getRates\?r\
    ateType=1\") output=user as-value]->\"data\")\
    \n    } on-error={}\
    \n\
    \n    :if ([:len \$freshRates] > 0) do={\
    \n        :local newCache \"\";\
    \n        :local remaining \$freshRates;\
    \n        :local parsing true;\
    \n        :while (\$parsing = true) do={\
    \n            :local pipeIdx [:find \$remaining \"|\"];\
    \n            :local entry \"\";\
    \n            :if ([:len [:tostr \$pipeIdx]] > 0) do={\
    \n                :set entry [:pick \$remaining 0 \$pipeIdx];\
    \n                :set remaining [:pick \$remaining (\$pipeIdx + 1) [:len \
    \$remaining]];\
    \n            } else={\
    \n                :set entry \$remaining;\
    \n                :set parsing false;\
    \n            }\
    \n            :if ([:len \$entry] > 0) do={\
    \n                :local p1 [:find \$entry \"#\"];\
    \n                :local p2 [:find \$entry \"#\" (\$p1 + 1)];\
    \n                :local p3 [:find \$entry \"#\" (\$p2 + 1)];\
    \n                :local p4 [:find \$entry \"#\" (\$p3 + 1)];\
    \n\
    \n                :local eAmt     [:tonum [:pick \$entry (\$p1 + 1) \$p2]]\
    ;\
    \n                :local eValMins [:tonum [:pick \$entry (\$p3 + 1) \$p4]]\
    ;\
    \n\
    \n                :local days (\$eValMins / 1440);\
    \n                :local rem  (\$eValMins % 1440);\
    \n                :local hrs  (\$rem / 60);\
    \n                :local mins (\$rem % 60);\
    \n                :local hStr [:tostr \$hrs];  :if (\$hrs  < 10) do={ :set\
    \_hStr  \"0\$hrs\";  }\
    \n                :local mStr [:tostr \$mins]; :if (\$mins < 10) do={ :set\
    \_mStr \"0\$mins\"; }\
    \n                :local valStr \"\";\
    \n                :if (\$days > 0) do={\
    \n                    :set valStr (\"\$days\" . \"d\$hStr:\$mStr:00\");\
    \n                } else={\
    \n                    :set valStr \"\$hStr:\$mStr:00\";\
    \n                }\
    \n\
    \n                :if ([:len \$newCache] > 0) do={ :set newCache (\$newCac\
    he . \",\"); }\
    \n                :set newCache (\$newCache . \"\$eAmt:\$valStr:\$eValMins\
    \");\
    \n\
    \n                :if ([:len \$minutesCache] > 0) do={ :set minutesCache (\
    \$minutesCache . \",\"); }\
    \n                :set minutesCache (\$minutesCache . \"\$eAmt:\$eValMins\
    \");\
    \n\
    \n                :if (\$eAmt = \$iSaleAmt) do={\
    \n                    :set foundValidity \$valStr;\
    \n                }\
    \n            }\
    \n        }\
    \n\
    \n        :if (\$newCache != \$cachedRates) do={\
    \n            /system script set [find name=\"cachedrates\"] source=\$newC\
    ache;\
    \n        }\
    \n\
    \n    } else={\
    \n        :foreach e in=[:toarray \$cachedRates] do={\
    \n            :local cp1 [:find \$e \":\"];\
    \n            :local cp2 [:find \$e \":\" (\$cp1 + 1)];\
    \n            :if ([:len [:tostr \$cp1]] > 0 && [:len [:tostr \$cp2]] > 0)\
    \_do={\
    \n                :local eAmt        [:tonum [:pick \$e 0 \$cp1]];\
    \n                :local eVal        [:pick \$e (\$cp1 + 1) \$cp2];\
    \n                :local eMinsStored [:tonum [:pick \$e (\$cp2 + 1) [:len \
    \$e]]];\
    \n\
    \n                :if (\$eAmt = \$iSaleAmt) do={\
    \n                    :set foundValidity \$eVal;\
    \n                }\
    \n\
    \n                :if ([:len \$minutesCache] > 0) do={ :set minutesCache (\
    \$minutesCache . \",\"); }\
    \n                :set minutesCache (\$minutesCache . \"\$eAmt:\$eMinsStor\
    ed\");\
    \n            }\
    \n        }\
    \n    }\
    \n\
    \n    :if ([:len \$foundValidity] = 0) do={\
    \n        :local remAmt \$iSaleAmt;\
    \n        :local totalMins 0;\
    \n        :local combined true;\
    \n\
    \n        :while (\$remAmt > 0 && \$combined = true) do={\
    \n            :set combined false;\
    \n            :local bestAmt 0;\
    \n            :local bestMins 0;\
    \n\
    \n            :foreach e in=[:toarray \$minutesCache] do={\
    \n                :local cp [:find \$e \":\"];\
    \n                :local eAmt [:tonum [:pick \$e 0 \$cp]];\
    \n                :local eMins [:tonum [:pick \$e (\$cp + 1) [:len \$e]]];\
    \n                :if (\$eAmt <= \$remAmt && \$eAmt > \$bestAmt) do={\
    \n                    :set bestAmt \$eAmt;\
    \n                    :set bestMins \$eMins;\
    \n                }\
    \n            }\
    \n\
    \n            :if (\$bestAmt > 0) do={\
    \n                :set totalMins (\$totalMins + \$bestMins);\
    \n                :set remAmt (\$remAmt - \$bestAmt);\
    \n                :set combined true;\
    \n            }\
    \n        }\
    \n\
    \n        :if (\$remAmt = 0 && \$totalMins > 0) do={\
    \n            :local days (\$totalMins / 1440);\
    \n            :local rem  (\$totalMins % 1440);\
    \n            :local hrs  (\$rem / 60);\
    \n            :local mins (\$rem % 60);\
    \n            :local hStr [:tostr \$hrs];  :if (\$hrs  < 10) do={ :set hSt\
    r  \"0\$hrs\";  }\
    \n            :local mStr [:tostr \$mins]; :if (\$mins < 10) do={ :set mSt\
    r \"0\$mins\"; }\
    \n            :log info \"combining validity\";\
    \n            :if (\$days > 0) do={\
    \n                :set foundValidity (\"\$days\" . \"d\$hStr:\$mStr:00\");\
    \n            } else={\
    \n                :set foundValidity \"\$hStr:\$mStr:00\";\
    \n            }\
    \n            :log info \"Combined validity for P\$iSaleAmt: \$foundValidi\
    ty\";\
    \n        }\
    \n    }\
    \n\
    \n    :if ([:len \$foundValidity] > 0) do={\
    \n        :set validity \$foundValidity;\
    \n    } else={\
    \n        :log warning \"No valid rate found for P\$iSaleAmt, session will\
    \_have the validity not added.\";\
    \n    }\
    \n}\
    \n\
    \n# --- Clear comment flag ---\
    \n/ip hotspot user set comment=\"\" [find name=\$user];\
    \n\
    \n# --- New Purchase: Scheduler + Notification (v7 Safe Arrays) ---\
    \n:if ([:len \$com] > 0) do={\
    \n    :if (\$validity != \"0m\") do={\
    \n        :local sc [/sys scheduler find name=\$user];\
    \n        :if ([:len \$sc] = 0) do={\
    \n            /sys sch add name=\"\$user\" disable=no start-date=\$date in\
    terval=\$validity \\\
    \n                on-event=\"/ip hotspot user remove [find name=\$user]; /\
    ip hotspot active remove [find user=\$user]; /ip hotspot cookie remove [fi\
    nd user=\$user]; /system sche remove [find name=\$user]; /file remove \\\"\
    \$hotspotFolder/data/\$macNoCol.txt\\\";\" \\\
    \n                policy=ftp,reboot,read,write,policy,test,password,sniff,\
    sensitive,romon;\
    \n            :delay 2s;\
    \n        } else={\
    \n            :local sint [/sys scheduler get \$sc interval];\
    \n            :if ([:len \$validity] > 0) do={\
    \n                /sys scheduler set \$sc interval (\$sint + \$validity);\
    \n            }\
    \n        }\
    \n    }\
    \n\
    \n    :local fileScheduler \"FILE\$macNoCol\";\
    \n    :local fsc [/sys scheduler find name=\$fileScheduler];\
    \n    :local validUntil [/sys scheduler get [find name=\$user] next-run];\
    \n    :if ([:len \$fsc] > 0) do={\
    \n        /system scheduler remove \$fsc;\
    \n    }\
    \n    :do {\
    \n        /system scheduler add name=\"\$fileScheduler\" interval=5 \\\
    \n            start-date=[/system clock get date] start-time=[/system cloc\
    k get time] disable=no \\\
    \n            policy=ftp,reboot,read,write,policy,test,password,sniff,sens\
    itive,romon \\\
    \n            on-event=(\"/system scheduler set \$fileScheduler interval 0\
    ;\\r\\n\".\\\
    \n                      \":do { /file remove \\\"\$hotspotFolder/data/\$ma\
    cNoCol.txt\\\" } on-error={};\\r\\n\".\\\
    \n                      \"/file add name=\\\"\$hotspotFolder/data/\$macNoC\
    ol.txt\\\" contents=\\\"\$user#\$validUntil\\\";\\r\\n\".\\\
    \n                      \":log warning \\\"parallel script executed succes\
    sfully.\\\";\\r\\n\")\
    \n    } on-error={ :log error \"parallel script creation error.\"; }\
    \n\
    \n    # --- Estimates ---\
    \n    :local currentday [:tonum [:pick \$date 8 10]];\
    \n    :local estimatedperday 0;\
    \n    :if (\$currentday > 0) do={ :set estimatedperday (\$mnthlysales / \$\
    currentday); }\
    \n    :local estimatedpermonth (\$estimatedperday * 30);\
    \n    :local iValidUntil [/system scheduler get [find name=\$user] next-ru\
    n];\
    \n\
    \n    # --- Login Notification ---\
    \n    :local loginMessage (\"Information:%0ACoin:%20\\E2\\82\\B1%20\$iSale\
    Amt%0AUser:%20\$user%0ADevice%20Name:%20\$deviceName%0ATotal%20Time:%20\$t\
    otaltime%0AUsed%20Time:%20\$totaluptime%0ARemaining%20Time:%20\$remainingt\
    %0AExpires%20On:%20\$iValidUntil%0A%0ACurrent:%0AToday%20Sales:%20\\E2\\82\
    \\B1%20\$iDailySales%0AIncome%20This%20Month:%20\\E2\\82\\B1%20\$iMonthSal\
    es%0AIncome%20This%20Year:%20\\E2\\82\\B1%20\$iYearSales%0AActive%20Users:\
    %20\$uactive%0A%0ASystem%20Information:%0ACPU%20Usage:%20\$cpuusage%25%0AR\
    emaining%20Memory:%20\$ramMB.\$ramdecimal%20MB%0ACurrent%20Throughput:%20\
    \$queueRate%0A%0AEstimates:%0AEstimated%20Per%20Day:%20\\E2\\82\\B1%20\$es\
    timatedperday%0AEstimated%20Per%20Month:%20\\E2\\82\\B1%20\$estimatedpermo\
    nth%0A%0A(Note:%20The%20Estimates%20are%20not%20the%20current%20sales.)%0A\
    %0ADate%20%26%20Timestamp:%20\$date%20\$time\");\
    \n    :if (\$isTelegram = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/s\
    endMessage\" \\\
    \n                http-method=post \\\
    \n                http-data=\"chat_id=\$iTGrChatID&text=\$loginMessage\" \
    \\\
    \n                output=none;\
    \n        } on-error={ :log error \"Telegram login notification failed.\";\
    \_}\
    \n    }\
    \n    :if (\$isDiscord = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\$iDiscordWebhook http-method=post \\\
    \n                http-data=(\"content=\" . \"```\$loginMessage```%0A** **\
    \") \\\
    \n                mode=https output=none;\
    \n        } on-error={ :log error \"Discord login notification failed.\"; \
    }\
    \n    }\
    \n}\
    \n\
    \n# --- Update max active users record (v7 Fix) ---\
    \n:local rawSource [/system script get [find name=\"maxactiveusers\"] sour\
    ce];\
    \n:local maxActiveUsers 0;\
    \n:if ([:len \$rawSource] > 0) do={\
    \n    :set maxActiveUsers [:tonum \$rawSource];\
    \n}\
    \n:if (\$uactive > \$maxActiveUsers) do={\
    \n    /system script set [find name=\"maxactiveusers\"] source=\"\$uactive\
    \";\
    \n}" on-logout="# ========================================================\
    ====\
    \n# Hotspot Logout Script (Optimized for RouterOS v7)\
    \n# ============================================================\
    \n\
    \n# --- MAC / Path Setup ---\
    \n:local mac       \$\"mac-address\";\
    \n:local macNoCol  (\"\$[:pick \$mac 0 2]\$[:pick \$mac 3 5]\$[:pick \$mac\
    \_6 8]\$[:pick \$mac 9 11]\$[:pick \$mac 12 14]\$[:pick \$mac 15 17]\");\
    \n:local hotspotFolder \"hotspot\";\
    \n\
    \n# --- Notification Config (fetch all upfront) ---\
    \n:local isTelegram      [:tonum [/system script get [find name=\"enablete\
    legram\"] source]];\
    \n:local isDiscord       [:tonum [/system script get [find name=\"enabledi\
    scord\"] source]];\
    \n:local iDiscordWebhook [/system script get [find name=\"discordwebhook\"\
    ] source];\
    \n:local iTBotToken      [/system script get [find name=\"bottoken\"] sour\
    ce];\
    \n:local iTGrChatID      [/system script get [find name=\"chatid\"] source\
    ];\
    \n\
    \n# --- Hotspot User (single find, reused throughout) ---\
    \n:local uID  [/ip hotspot user find name=\$user];\
    \n:local com  \"\";\
    \n:local uLimit  0s;\
    \n:local uUptime 0s;\
    \n:if ([:len \$uID] > 0) do={\
    \n    :set com    [/ip hotspot user get \$uID comment];\
    \n    :set uLimit [/ip hotspot user get \$uID limit-uptime];\
    \n    :set uUptime [/ip hotspot user get \$uID uptime];\
    \n}\
    \n\
    \n# --- Expire user if time is used up ---\
    \n:if (\$uLimit > 0s && \$uLimit <= \$uUptime) do={\
    \n    :if ([:len \$uID] > 0) do={ /ip hotspot user remove \$uID; }\
    \n    :do { /file remove \"\$hotspotFolder/data/\$macNoCol.txt\"; } on-err\
    or={};\
    \n    :local uSch [/system scheduler find name=\$user];\
    \n    :if ([:len \$uSch] > 0) do={ /system scheduler remove \$uSch; }\
    \n    # Clear uID so we don't try to write a file for them below\
    \n    :set uID \"\"; \
    \n}\
    \n\
    \n# --- Clean up file scheduler (v7 Safe Arrays) ---\
    \n:local fileScheduler \"FILE\$macNoCol\";\
    \n:local fSch [/system scheduler find name=\$fileScheduler];\
    \n:if ([:len \$fSch] > 0) do={\
    \n    /system scheduler remove \$fSch;\
    \n}\
    \n\
    \n# --- Clean up retry scheduler (v7 Safe Arrays) ---\
    \n:local retryScheduler \"RETRY\$macNoCol\";\
    \n:local rSch [/system scheduler find name=\$retryScheduler];\
    \n:if ([:len \$rSch] > 0) do={\
    \n    /system scheduler remove \$rSch;\
    \n}\
    \n\
    \n# --- Cause-based Notifications ---\
    \n\
    \n# Session timeout\
    \n:if (\$cause = \"session timeout\") do={\
    \n    :local timeoutMessage (\"\$user%20ran%20out%20of%20time!\");\
    \n    :if (\$isTelegram = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/s\
    endMessage\" \\\
    \n                http-method=post \\\
    \n                http-data=\"chat_id=\$iTGrChatID&text=\$timeoutMessage\"\
    \_\\\
    \n                output=none;\
    \n        } on-error={ :log warning \"logout: Telegram session timeout not\
    ify failed\"; }\
    \n    }\
    \n    :if (\$isDiscord = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\$iDiscordWebhook http-method=post \\\
    \n                http-data=(\"content=\" . \"```\$timeoutMessage```%0A** \
    **\") \\\
    \n                mode=https output=none;\
    \n        } on-error={ :log warning \"logout: Discord session timeout noti\
    fy failed\"; }\
    \n    }\
    \n}\
    \n\
    \n# User-requested pause\
    \n:if ([:len \$com] = 0 && \$cause = \"user request\") do={\
    \n    :local pauseMessage (\"\$user%20paused%20time.\");\
    \n    :if (\$isTelegram = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/s\
    endMessage\" \\\
    \n                http-method=post \\\
    \n                http-data=\"chat_id=\$iTGrChatID&text=\$pauseMessage\" \
    \\\
    \n                output=none;\
    \n        } on-error={ :log warning \"logout: Telegram pause notify failed\
    \"; }\
    \n    }\
    \n    :if (\$isDiscord = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\$iDiscordWebhook http-method=post \\\
    \n                http-data=(\"content=\" . \"```\$pauseMessage```%0A** **\
    \") \\\
    \n                mode=https output=none;\
    \n        } on-error={ :log warning \"logout: Discord pause notify failed\
    \"; }\
    \n    }\
    \n}\
    \n\
    \n# Keepalive timeout\
    \n:if (\$cause = \"keepalive timeout\") do={\
    \n    :local timeoutMessage (\"automatically%20paused%20time%20for%20\$use\
    r\");\
    \n    :if (\$isTelegram = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/s\
    endMessage\" \\\
    \n                http-method=post \\\
    \n                http-data=\"chat_id=\$iTGrChatID&text=\$timeoutMessage\"\
    \_\\\
    \n                output=none;\
    \n        } on-error={ :log warning \"logout: Telegram keepalive notify fa\
    iled\"; }\
    \n    }\
    \n    :if (\$isDiscord = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\$iDiscordWebhook http-method=post \\\
    \n                http-data=(\"content=\" . \"```\$timeoutMessage```%0A** \
    **\") \\\
    \n                mode=https output=none;\
    \n        } on-error={ :log warning \"logout: Discord keepalive notify fai\
    led\"; }\
    \n    }\
    \n}\
    \n\
    \n# Admin kick\
    \n:if (\$cause = \"admin reset\") do={\
    \n    :local kickMessage (\"admin%20kicked%20\$user\");\
    \n    :if (\$isTelegram = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/s\
    endMessage\" \\\
    \n                http-method=post \\\
    \n                http-data=\"chat_id=\$iTGrChatID&text=\$kickMessage\" \\\
    \n                output=none;\
    \n        } on-error={ :log warning \"logout: Telegram admin kick notify f\
    ailed\"; }\
    \n    }\
    \n    :if (\$isDiscord = 1) do={\
    \n        :do {\
    \n            /tool fetch url=\$iDiscordWebhook http-method=post \\\
    \n                http-data=(\"content=\" . \"```\$kickMessage```%0A** **\
    \") \\\
    \n                mode=https output=none;\
    \n        } on-error={ :log warning \"logout: Discord admin kick notify fa\
    iled\"; }\
    \n    }\
    \n}\
    \n# --- Clear Session Backup Comment ---\
    \n:local uSch [/system scheduler find name=\$user];\
    \n:if ([:len \$uSch] > 0) do={\
    \n    /system scheduler set \$uSch comment=\"\";\
    \n}\
    \n# --- Write session file if user still exists (v7 Native Add) ---\
    \n:if ([:len \$uID] > 0) do={\
    \n    :local schID [/system scheduler find name=\$user];\
    \n    :if ([:len \$schID] > 0) do={\
    \n        :local iValidUntil [/system scheduler get \$schID next-run];\
    \n        :local myfile \"\$hotspotFolder/data/\$user.txt\";\
    \n        :if ([:len [/file find name=\$myfile]] = 0) do={\
    \n            :do {\
    \n                /file add name=\$myfile contents=\"\$user#\$iValidUntil\
    \";\
    \n            } on-error={ :log warning \"logout: Failed to create session\
    \_file for \$user\"; }\
    \n        }\
    \n    }\
    \n}"

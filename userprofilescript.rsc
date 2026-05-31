# ==============================================================================
# LMEPISOWIFI USER PROFILES & SCHEDULERS SCRIPT (v7 Optimized)
# ==============================================================================

# --- Create Missing System Scripts ---
:foreach sName in={"enabletelegram";"bottoken";"chatid";"enablediscord";"discordwebhook";"todayincome";"monthlyincome";"yearlyincome";"maxactiveusers";"cachedrates"} do={
    :if ([:len [/system script find name=$sName]] = 0) do={
        :if ($sName = "cachedrates") do={
            /system script add name=$sName source="" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon;
        } else={
            /system script add name=$sName source="0" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon;
        }
        :log warning "Created missing script: $sName";
    }
}
/system ntp client set enabled=yes
:local ntpAlreadySet false;
:do {
    :local curServers [/system ntp client get servers];
    :if ($curServers = "ntp.pagasa.dost.gov.ph;0.asia.pool.ntp.org") do={
        :set ntpAlreadySet true;
    }
} on-error={};

:if ($ntpAlreadySet = false) do={
    :do {
        /system ntp client set enabled=yes servers=ntp.pagasa.dost.gov.ph,0.asia.pool.ntp.org
    } on-error={}
    }
}

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
    add name="Reset Daily Income" interval=1h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
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
    set [find name="Reset Daily Income"] interval=1h on-event={
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
    add name="reset maxactiveusers" interval=1h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
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
    set [find name="reset maxactiveusers"] interval=1h on-event={
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
    add name="resetmonthly" interval=1h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
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
    set [find name="resetmonthly"] interval=1h on-event={
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
    add name="reset yearly" interval=1h start-time=00:00:01 policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon on-event={
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
    set [find name="reset yearly"] interval=1h on-event={
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
set [ find default=yes ] add-mac-cookie=no keepalive-timeout=3m name=autospeedlimit shared-users=2 \
on-login={
    # ============================================================
    # Hotspot Login Script (Optimized for RouterOS v7)
    # ============================================================
    :local date [/system clock get date];
    :local time [/system clock get time];

    :local ifName "ether1";
    :local rxBps; :local txBps;
    /interface monitor-traffic $ifName once do={
        :set rxBps $"rx-bits-per-second";
        :set txBps $"tx-bits-per-second";
    }
    :local rxKbps ($rxBps / 1000);
    :local txKbps ($txBps / 1000);

    :local rxStr "";
    :if ($rxKbps >= 1000) do={ :set rxStr (($rxKbps / 1000) . "." . (($rxKbps % 1000) / 100) . " Mbps"); } else={ :set rxStr ("$rxKbps Kbps"); }
    :local txStr "";
    :if ($txKbps >= 1000) do={ :set txStr (($txKbps / 1000) . "." . (($txKbps % 1000) / 100) . " Mbps"); } else={ :set txStr ("$txKbps Kbps"); }
    :local queueRate ("$rxStr | $txStr");

    :local mac    $"mac-address";
    :local addr   $"address";
    :local macNoCol ("$[:pick $mac 0 2]$[:pick $mac 3 5]$[:pick $mac 6 8]$[:pick $mac 9 11]$[:pick $mac 12 14]$[:pick $mac 15 17]");

    :local deviceName "N/A";
    :local dLease [/ip dhcp-server lease find mac-address=$mac];
    :if ([:len $dLease] > 0) do={
        :local hostName [/ip dhcp-server lease get $dLease host-name];
        :if ([:len $hostName] > 0) do={ :set deviceName $hostName; }
    }

    :local uID [/ip hotspot user find name=$user];
    :local limit    [/ip hotspot user get $uID limit-uptime];
    :local uptime   [/ip hotspot user get $uID uptime];
    :local com      [/ip hotspot user get $uID comment];
    :local aUsrNote [:toarray $com];
    :local iSaleAmt [:tonum ($aUsrNote->1)];

    :local totaltime $limit;
    :local remainingt ($limit - $uptime);
    :local totaluptime ($limit - $remainingt);
    :local validity "";

    :local cpuusage [/system resource get cpu-load];
    :local freeRam  [/system resource get free-memory];
    :local ramMB    ($freeRam / 1048576);
    :local ramdecimal (($freeRam % 1048576) / 104858);

    :local uactive [/ip hotspot active print count-only];

    :local hotspotFolder "hotspot";
    :local isTelegram  [:tonum [/system script get [find name="enabletelegram"] source]];
    :local iTBotToken  [/system script get [find name="bottoken"] source];
    :local iTGrChatID  [/system script get [find name="chatid"] source];
    :local isDiscord   [:tonum [/system script get [find name="enablediscord"] source]];
    :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];

    :local todaysales  [:tonum [/system script get [find name="todayincome"] source]];
    :local mnthlysales [:tonum [/system script get [find name="monthlyincome"] source]];
    :local yearlysales [:tonum [/system script get [find name="yearlyincome"] source]];
    :local iDailySales ($iSaleAmt + $todaysales);
    :local iMonthSales ($iSaleAmt + $mnthlysales);
    :local iYearSales  ($iSaleAmt + $yearlysales);

    :if ([:len $com] > 0) do={
        /system script set [find name="todayincome"] source="$iDailySales";
        /system script set [find name="monthlyincome"] source="$iMonthSales";
        /system script set [find name="yearlyincome"] source="$iYearSales";
        :set validity [:pick $com 0 [:find $com ","]];
    }

    :if ([:len $com] = 0) do={
        :local rtimeMessage ("$user%20resumed%20time,%20remaining%20time%20is%20$remainingt%0AActive%20Users:%20$uactive");
        :if ($isTelegram = 1) do={
            :do { /tool fetch url="https://api.telegram.org/bot$iTBotToken/sendMessage" http-method=post http-data="chat_id=$iTGrChatID&text=$rtimeMessage" output=none; } on-error={}
        }
        :if ($isDiscord = 1) do={
            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "```$rtimeMessage```%0A** **") mode=https output=none; } on-error={}
        }
    }

    :if ($validity = "0m") do={
        :local vendorIp "10.0.0.5";
        :local cachedRates [/system script get [find name="cachedrates"] source];
        :local foundValidity "";
        :local freshRates "";
        :local minutesCache "";

        :do { :set freshRates ([/tool fetch url=("http://10.0.0.5/getRates?rateType=1") output=user as-value]->"data") } on-error={}

        :if ([:len $freshRates] > 0) do={
            :local newCache ""; :local remaining $freshRates; :local parsing true;
            :while ($parsing = true) do={
                :local pipeIdx [:find $remaining "|"]; :local entry "";
                :if ([:len [:tostr $pipeIdx]] > 0) do={
                    :set entry [:pick $remaining 0 $pipeIdx]; :set remaining [:pick $remaining ($pipeIdx + 1) [:len $remaining]];
                } else={ :set entry $remaining; :set parsing false; }
                :if ([:len $entry] > 0) do={
                    :local p1 [:find $entry "#"]; :local p2 [:find $entry "#" ($p1 + 1)];
                    :local p3 [:find $entry "#" ($p2 + 1)]; :local p4 [:find $entry "#" ($p3 + 1)];
                    :local eAmt [:tonum [:pick $entry ($p1 + 1) $p2]];
                    :local eValMins [:tonum [:pick $entry ($p3 + 1) $p4]];

                    :local days ($eValMins / 1440); :local rem ($eValMins % 1440);
                    :local hrs ($rem / 60); :local mins ($rem % 60);
                    :local hStr [:tostr $hrs]; :if ($hrs < 10) do={ :set hStr "0$hrs"; }
                    :local mStr [:tostr $mins]; :if ($mins < 10) do={ :set mStr "0$mins"; }
                    :local valStr "";
                    :if ($days > 0) do={ :set valStr ("$days" . "d$hStr:$mStr:00"); } else={ :set valStr "$hStr:$mStr:00"; }

                    :if ([:len $newCache] > 0) do={ :set newCache ($newCache . ","); }
                    :set newCache ($newCache . "$eAmt:$valStr:$eValMins");
                    :if ([:len $minutesCache] > 0) do={ :set minutesCache ($minutesCache . ","); }
                    :set minutesCache ($minutesCache . "$eAmt:$eValMins");
                    :if ($eAmt = $iSaleAmt) do={ :set foundValidity $valStr; }
                }
            }
            :if ($newCache != $cachedRates) do={ /system script set [find name="cachedrates"] source=$newCache; }
        } else={
            :foreach e in=[:toarray $cachedRates] do={
                :local cp1 [:find $e ":"]; :local cp2 [:find $e ":" ($cp1 + 1)];
                :if ([:len [:tostr $cp1]] > 0 && [:len [:tostr $cp2]] > 0) do={
                    :local eAmt [:tonum [:pick $e 0 $cp1]]; :local eVal [:pick $e ($cp1 + 1) $cp2];
                    :local eMinsStored [:tonum [:pick $e ($cp2 + 1) [:len $e]]];
                    :if ($eAmt = $iSaleAmt) do={ :set foundValidity $eVal; }
                    :if ([:len $minutesCache] > 0) do={ :set minutesCache ($minutesCache . ","); }
                    :set minutesCache ($minutesCache . "$eAmt:$eMinsStored");
                }
            }
        }

        :if ([:len $foundValidity] = 0) do={
            :local remAmt $iSaleAmt; :local totalMins 0; :local combined true;
            :while ($remAmt > 0 && $combined = true) do={
                :set combined false; :local bestAmt 0; :local bestMins 0;
                :foreach e in=[:toarray $minutesCache] do={
                    :local cp [:find $e ":"]; :local eAmt [:tonum [:pick $e 0 $cp]]; :local eMins [:tonum [:pick $e ($cp + 1) [:len $e]]];
                    :if ($eAmt <= $remAmt && $eAmt > $bestAmt) do={ :set bestAmt $eAmt; :set bestMins $eMins; }
                }
                :if ($bestAmt > 0) do={ :set totalMins ($totalMins + $bestMins); :set remAmt ($remAmt - $bestAmt); :set combined true; }
            }
            :if ($remAmt = 0 && $totalMins > 0) do={
                :local days ($totalMins / 1440); :local rem ($totalMins % 1440);
                :local hrs ($rem / 60); :local mins ($rem % 60);
                :local hStr [:tostr $hrs]; :if ($hrs < 10) do={ :set hStr "0$hrs"; }
                :local mStr [:tostr $mins]; :if ($mins < 10) do={ :set mStr "0$mins"; }
                :if ($days > 0) do={ :set foundValidity ("$days" . "d$hStr:$mStr:00"); } else={ :set foundValidity "$hStr:$mStr:00"; }
            }
        }

        :if ([:len $foundValidity] > 0) do={ :set validity $foundValidity; } else={ :log warning "No valid rate found"; }
    }

    /ip hotspot user set comment="" [find name=$user];

    :if ([:len $com] > 0) do={
        :if ($validity != "0m") do={
            :local sc [/sys scheduler find name=$user];
            :if ([:len $sc] = 0) do={
                /sys sch add name="$user" disable=no start-date=$date interval=$validity \
                    on-event="/ip hotspot user remove [find name=$user]; /ip hotspot active remove [find user=$user]; /ip hotspot cookie remove [find user=$user]; /system sche remove [find name=$user]; /file remove \"$hotspotFolder/data/$macNoCol.txt\";" \
                    policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon;
                :delay 2s;
            } else={
                :local sint [/sys scheduler get $sc interval];
                :if ([:len $validity] > 0) do={ /sys scheduler set $sc interval ($sint + $validity); }
            }
        }

        :local fileScheduler "FILE$macNoCol";
        :local fsc [/sys scheduler find name=$fileScheduler];
        :local validUntil [/sys scheduler get [find name=$user] next-run];
        :if ([:len $fsc] > 0) do={ /system scheduler remove $fsc; }
        :do {
            /system scheduler add name="$fileScheduler" interval=5 \
                start-date=[/system clock get date] start-time=[/system clock get time] disable=no \
                policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
                on-event=("/system scheduler set $fileScheduler interval 0;\r\n".\
                          ":do { /file remove \"$hotspotFolder/data/$macNoCol.txt\" } on-error={};\r\n".\
                          "/file add name=\"$hotspotFolder/data/$macNoCol.txt\" contents=\"$user#$validUntil\";\r\n")
        } on-error={}

        :local currentday [:tonum [:pick $date 8 10]];
        :local estimatedperday 0;
        :if ($currentday > 0) do={ :set estimatedperday ($mnthlysales / $currentday); }
        :local estimatedpermonth ($estimatedperday * 30);
        :local iValidUntil [/system scheduler get [find name=$user] next-run];

        :local loginMessage ("Information:%0ACoin:%20\E2\82\B1%20$iSaleAmt%0AUser:%20$user%0ADevice%20Name:%20$deviceName%0ATotal%20Time:%20$totaltime%0AUsed%20Time:%20$totaluptime%0ARemaining%20Time:%20$remainingt%0AExpires%20On:%20$iValidUntil%0A%0ACurrent:%0AToday%20Sales:%20\E2\82\B1%20$iDailySales%0AIncome%20This%20Month:%20\E2\82\B1%20$iMonthSales%0AIncome%20This%20Year:%20\E2\82\B1%20$iYearSales%0AActive%20Users:%20$uactive%0A%0ASystem%20Information:%0ACPU%20Usage:%20$cpuusage%25%0ARemaining%20Memory:%20$ramMB.$ramdecimal%20MB%0ACurrent%20Throughput:%20$queueRate%0A%0AEstimates:%0AEstimated%20Per%20Day:%20\E2\82\B1%20$estimatedperday%0AEstimated%20Per%20Month:%20\E2\82\B1%20$estimatedpermonth%0A%0A(Note:%20The%20Estimates%20are%20not%20the%20current%20sales.)%0A%0ADate%20%26%20Timestamp:%20$date%20$time");
        :if ($isTelegram = 1) do={
            :do { /tool fetch url="https://api.telegram.org/bot$iTBotToken/sendMessage" http-method=post http-data="chat_id=$iTGrChatID&text=$loginMessage" output=none; } on-error={}
        }
        :if ($isDiscord = 1) do={
            :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "```$loginMessage```%0A** **") mode=https output=none; } on-error={}
        }
    }

    :local rawSource [/system script get [find name="maxactiveusers"] source];
    :local maxActiveUsers 0;
    :if ([:len $rawSource] > 0) do={ :set maxActiveUsers [:tonum $rawSource]; }
    :if ($uactive > $maxActiveUsers) do={ /system script set [find name="maxactiveusers"] source="$uactive"; }
} \
on-logout={
    # ============================================================
    # Hotspot Logout Script (Optimized for RouterOS v7)
    # ============================================================
    :local mac $"mac-address";
    :local macNoCol ("$[:pick $mac 0 2]$[:pick $mac 3 5]$[:pick $mac 6 8]$[:pick $mac 9 11]$[:pick $mac 12 14]$[:pick $mac 15 17]");
    :local hotspotFolder "hotspot";

    :local isTelegram [:tonum [/system script get [find name="enabletelegram"] source]];
    :local isDiscord [:tonum [/system script get [find name="enablediscord"] source]];
    :local iDiscordWebhook [/system script get [find name="discordwebhook"] source];
    :local iTBotToken [/system script get [find name="bottoken"] source];
    :local iTGrChatID [/system script get [find name="chatid"] source];

    :local uID [/ip hotspot user find name=$user];
    :local com ""; :local uLimit 0s; :local uUptime 0s;
    :if ([:len $uID] > 0) do={
        :set com [/ip hotspot user get $uID comment];
        :set uLimit [/ip hotspot user get $uID limit-uptime];
        :set uUptime [/ip hotspot user get $uID uptime];
    }

    :if ($uLimit > 0s && $uLimit <= $uUptime) do={
        :if ([:len $uID] > 0) do={ /ip hotspot user remove $uID; }
        :do { /file remove "$hotspotFolder/data/$macNoCol.txt"; } on-error={};
        :local uSch [/system scheduler find name=$user];
        :if ([:len $uSch] > 0) do={ /system scheduler remove $uSch; }
        :set uID "";
    }

    :local fSch [/system scheduler find name="FILE$macNoCol"];
    :if ([:len $fSch] > 0) do={ /system scheduler remove $fSch; }
    
    :local rSch [/system scheduler find name="RETRY$macNoCol"];
    :if ([:len $rSch] > 0) do={ /system scheduler remove $rSch; }

    :if ($cause = "session timeout") do={
        :local timeoutMessage ("$user%20ran%20out%20of%20time!");
        :if ($isTelegram = 1) do={ :do { /tool fetch url="https://api.telegram.org/bot$iTBotToken/sendMessage" http-method=post http-data="chat_id=$iTGrChatID&text=$timeoutMessage" output=none; } on-error={} }
        :if ($isDiscord = 1) do={ :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "```$timeoutMessage```%0A** **") mode=https output=none; } on-error={} }
    }

    :if ([:len $com] = 0 && $cause = "user request") do={
        :local pauseMessage ("$user%20paused%20time.");
        :if ($isTelegram = 1) do={ :do { /tool fetch url="https://api.telegram.org/bot$iTBotToken/sendMessage" http-method=post http-data="chat_id=$iTGrChatID&text=$pauseMessage" output=none; } on-error={} }
        :if ($isDiscord = 1) do={ :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "```$pauseMessage```%0A** **") mode=https output=none; } on-error={} }
    }

    :if ($cause = "keepalive timeout") do={
        :local timeoutMessage ("automatically%20paused%20time%20for%20$user");
        :if ($isTelegram = 1) do={ :do { /tool fetch url="https://api.telegram.org/bot$iTBotToken/sendMessage" http-method=post http-data="chat_id=$iTGrChatID&text=$timeoutMessage" output=none; } on-error={} }
        :if ($isDiscord = 1) do={ :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "```$timeoutMessage```%0A** **") mode=https output=none; } on-error={} }
    }

    :if ($cause = "admin reset") do={
        :local kickMessage ("admin%20kicked%20$user");
        :if ($isTelegram = 1) do={ :do { /tool fetch url="https://api.telegram.org/bot$iTBotToken/sendMessage" http-method=post http-data="chat_id=$iTGrChatID&text=$kickMessage" output=none; } on-error={} }
        :if ($isDiscord = 1) do={ :do { /tool fetch url=$iDiscordWebhook http-method=post http-data=("content=" . "```$kickMessage```%0A** **") mode=https output=none; } on-error={} }
    }

    # --- Clear Backup Comment so normal resumes don't revert to old timestamps ---
    :local uSch [/system scheduler find name=$user];
    :if ([:len $uSch] > 0) do={ /system scheduler set $uSch comment=""; }

    # --- Write Session File ---
    :if ([:len $uID] > 0) do={
        :if ([:len $uSch] > 0) do={
            :local iValidUntil [/system scheduler get $uSch next-run];
            :local myfile "$hotspotFolder/data/$user.txt";
            :if ([:len [/file find name=$myfile]] = 0) do={
                :do { /file add name=$myfile contents="$user#$iValidUntil"; } on-error={}
            }
        }
    }
}

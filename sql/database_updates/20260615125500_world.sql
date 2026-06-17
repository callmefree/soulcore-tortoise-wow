-- Fix quest 7848 (Alliance version of Molten Core attunement)
-- Quest 7487 = Horde version, Quest 7848 = Alliance version
-- The quest_template entry for 7848 was missing from base SQL

SET @ENTRY := 7848;

-- Add quest_template entry if not exists
INSERT IGNORE INTO `quest_template` VALUES 
(7848,2,2717,55,0,60,81,0,589,0,0,0,0,0,0,0,0,0,0,0,64,0,0,0,0,0,0,0,0,'Attunement to the Core','Rifts stir, tear, and collapse all around us, $r. Not two paces from where I stand is a tear leading through the depths of Blackrock Mountain, into the maw of the Firelord.$B$BSurprised? Pity... The mortal races cannot comprehend that which they cannot see, touch, or feel.$B$BI assure you, the portal is there and access is possible.$B$BI\'ve piqued your interest? Attunement is simple. Venture into Blackrock Depths and retrieve a core fragment. Return to me and I shall attune your essence with the portal.','Venture to the Molten Core entry portal in Blackrock Depths and recover a Core Fragment. Return to Lothos Riftwaker in Blackrock Mountain when you have recovered the Core Fragment.','I am now able to transport you to the Molten Core. Ask and it shall be done.','You must attune your soul with the Molten Core before access is granted.','','','','','',18412,0,0,0,1,0,0,0,18412,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6600,0,39600,0,22877,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0);

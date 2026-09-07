#include <gtest/gtest.h>
#include "client/bestiaryparser.h"

namespace {
void bytes(InputMessage& msg, std::initializer_list<unsigned char> data)
{
    msg.setBuffer(std::string(data.begin(), data.end()));
    msg.setReadPos(msg.getReadPos() - data.size());
}
}

TEST(BestiaryOverview, Summer2026LockedAndRevealedEntriesStayAligned)
{
    InputMessage msg;
    // Two entries, then mastery points and a following opcode sentinel.
    bytes(msg, {1,0, 0,0, 0,0, 2,0, 1,2, 3,0, 25,0, 7,0, 0xA0});
    const auto locked = bestiary::readOverviewEntry(msg, true, true);
    const auto revealed = bestiary::readOverviewEntry(msg, true, true);
    EXPECT_EQ(locked.id, 1);
    EXPECT_EQ(locked.currentLevel, 0);
    EXPECT_EQ(locked.occurrence, 0);
    EXPECT_EQ(revealed.id, 2);
    EXPECT_EQ(revealed.currentLevel, 2);
    EXPECT_EQ(revealed.occurrence, 3);
    EXPECT_EQ(revealed.creatureAnimusMasteryBonus, 25);
    EXPECT_EQ(msg.getU16(), 7);
    EXPECT_EQ(msg.getU8(), 0xA0);
    EXPECT_TRUE(msg.eof());
}

TEST(BestiaryOverview, PreSummerAnimusAndLegacyRemainSupported)
{
    InputMessage msg;
    bytes(msg, {1,0, 0, 10,0, 0xA0});
    EXPECT_EQ(bestiary::readOverviewEntry(msg, true, false).creatureAnimusMasteryBonus, 10);
    EXPECT_EQ(msg.getU8(), 0xA0);
    bytes(msg, {2,0, 1,3, 0xA0});
    const auto legacy = bestiary::readOverviewEntry(msg, false, false);
    EXPECT_EQ(legacy.occurrence, 3);
    EXPECT_EQ(legacy.creatureAnimusMasteryBonus, 0);
    EXPECT_EQ(msg.getU8(), 0xA0);
}

TEST(BestiaryOverview, TruncatedAndInvalidEntriesUseProtocolExceptions)
{
    InputMessage msg;
    bytes(msg, {1,0, 0});
    EXPECT_THROW(bestiary::readOverviewEntry(msg, true, true), stdext::exception);
    bytes(msg, {1,0, 1,255});
    EXPECT_THROW(bestiary::readOverviewEntry(msg, true, true), stdext::exception);
}

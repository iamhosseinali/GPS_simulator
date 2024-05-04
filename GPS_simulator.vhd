----------------------------------------------------------------------------------
-- Engineer: Hosseinali
-- Create Date: 02/09/2024 04:33:33 PM
-- Module Name: GPS_simulator - Behavioral
-- Project Name: PMU
-- Target Devices: ZYNQ7010
-- Description: This design immitates the nmea output of the GPS modules, this is fully synthesizable and all of the calculations are done by ur PC not ur target device.  
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity GPS_simulator is
generic
(
    IP_FREQUENCY : integer := 100000000;
    Send_interval: integer := 1; -- How many NMEA sentences should be sent per second. 
    First_sentence : string := "$GPGGA,161229.487,3723.2475,N,12158.3416,W,1,07,1.0,9.0,M,,,,0000*18";
    Second_sentence : string := "$GPZDA,172809.45,12,07,1996,00,00*45"
);
    Port (     
            clk         : in STD_LOGIC;
            tREADY      : in STD_LOGIC;
            tVALID      : out STD_LOGIC;
            o_data      : out STD_LOGIC_VECTOR (7 downto 0)
        );
end GPS_simulator;

architecture Behavioral of GPS_simulator is
    subtype slv is std_logic_vector;

    -- This function converts strings to binary with std_logic_vector type -- 
function to_slv(s: string) return std_logic_vector is 
    constant ss: string(1 to s'length) := s; 
    variable answer: std_logic_vector(1 to 8 * s'length); 
    variable p: integer; 
    variable c: integer; 
begin 
    for i in ss'range loop
        p := 8 * i;
        c := character'pos(ss(i));
        answer(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
    end loop; 
    return answer;
end function;
constant Num_of_First_sentence_letters : integer := First_sentence'length;  -- number of first sentence characters. 
constant Num_of_Second_sentence_letters : integer := Second_sentence'length; -- number of second sentence characters. 
constant First_sentence_msb : integer := Num_of_First_sentence_letters*8-1;
constant second_sentence_msb : integer := Num_of_Second_sentence_letters*8-1;
constant binary_First_sentence : STD_LOGIC_VECTOR(First_sentence_msb downto 0) := to_slv(First_sentence); 
constant binary_second_sentence : STD_LOGIC_VECTOR(second_sentence_msb downto 0) := to_slv(Second_sentence);
constant Send_interval_cycle    : integer := IP_FREQUENCY/Send_interval; 
signal cnt : unsigned(29 downto 0) := (others=>'0'); 
signal character_index : unsigned(7 downto 0) := to_unsigned(1,8);

type frsplitterType is array(1 to Num_of_First_sentence_letters) of std_logic_vector(7 downto 0);
signal splt_First_sentence : frsplitterType := (others=>(others=>'0'));
type sesplitterType is array(1 to Num_of_Second_sentence_letters) of std_logic_vector(7 downto 0);
signal splt_second_sentence : sesplitterType := (others=>(others=>'0'));

type fsmType is (idle,sending_first,gap,gap_1,sending_sec,interval,waiting); 
signal FSM : fsmType := idle; 
begin
Fr_assignment:for i in 1 to Num_of_First_sentence_letters generate 
    splt_First_sentence(i) <= binary_First_sentence(First_sentence_msb-((i-1)*8) downto First_sentence_msb-(i*8-1));
end generate; 
se_assignment:for i in 1 to Num_of_Second_sentence_letters generate 
    splt_second_sentence(i) <= binary_second_sentence(second_sentence_msb-((i-1)*8) downto second_sentence_msb-(i*8-1));
end generate; 
process(clk)
begin
if rising_edge(clk) then
    tVALID        <= '0';
    if(FSM /= idle) then 
        cnt         <= cnt +1;  
    end if;  

    case FSM is 
        when idle => 
            FSM     <= sending_first; 
            if(tREADY = '0') then 
                FSM     <= idle; 
            end if; 
        when sending_first => 
            tVALID  <= '1'; 
            o_data  <= splt_First_sentence(to_integer(character_index));
            FSM     <= gap; 
        when gap => 
            if(tREADY ='1') then
                FSM             <= sending_first; 
                character_index <= character_index +1; 
            end if; 
            if(character_index = to_unsigned(Num_of_First_sentence_letters,8) and tREADY = '1') then --and busy_pre = '1'
                FSM             <= sending_sec;
                character_index <= to_unsigned(1,8);
            end if; 
        when sending_sec => 
            tVALID    <= '1'; 
            o_data  <= splt_second_sentence(to_integer(character_index));
            FSM     <= gap_1; 
        when gap_1 => 
            if(tREADY ='1') then
                FSM             <= sending_sec; 
                character_index <= character_index +1; 
            end if;             
            if(character_index = to_unsigned(Num_of_second_sentence_letters,8) and tREADY = '1' ) then
                FSM             <= interval;
                character_index <= to_unsigned(1,8);
            end if;         
        when interval =>
            if(cnt = to_unsigned(Send_interval_cycle-1,30)) then 
                FSM         <= idle; 
                cnt         <= (others=>'0');
            end if; 
        when others => 
    end case; 

end if; 
end process; 
end Behavioral;

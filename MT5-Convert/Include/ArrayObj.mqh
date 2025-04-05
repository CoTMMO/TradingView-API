//+------------------------------------------------------------------+
//|                                                    ArrayObj.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Array of Objects Class                                             |
//+------------------------------------------------------------------+
class CArrayObj
{
private:
   void*             m_items[];
   int               m_size;
   int               m_count;
   
public:
                     CArrayObj()
   {
      m_size = 0;
      m_count = 0;
   }
   
                    ~CArrayObj()
   {
      Clear();
   }
   
   void              Clear()
   {
      if(m_size > 0) {
         ArrayResize(m_items, 0);
         m_size = 0;
         m_count = 0;
      }
   }
   
   int               Total() const { return m_count; }
   
   bool              Add(void* item)
   {
      if(m_count >= m_size) {
         int newSize = (m_size == 0) ? 16 : m_size * 2;
         if(!ArrayResize(m_items, newSize)) return false;
         m_size = newSize;
      }
      
      m_items[m_count++] = item;
      return true;
   }
   
   void*             At(int index) const
   {
      if(index < 0 || index >= m_count) return NULL;
      return m_items[index];
   }
   
   void              Execute()
   {
      // This is a placeholder for the Execute method
      // In a real implementation, this would call a function pointer
   }
}; 